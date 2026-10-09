extends "res://tests/framework/story_test.gd"
## Tests for TaleText interpolation and TaleParser.parse_expression.


func _split(text: String) -> Array:
	var result := TaleText.split_interpolation(text)
	var described := []
	for part in result["parts"]:
		described.append(part.to_sexpr() if part is TaleExpr else part)
	return [described, Array(result["errors"])]


func test_plain_text() -> void:
	assert_eq(_split("Hello."), [["Hello."], []])
	assert_eq(_split(""), [[], []])


func test_values_are_split_out() -> void:
	assert_eq(_split("Hi {name}, you have {gold * 2} gold."),
		[["Hi ", "name", ", you have ", "(* gold 2)", " gold."], []])


func test_double_braces_are_literal() -> void:
	assert_eq(_split("{{not a value}}"), [["{not a value}"], []])


func test_nested_braces_and_strings() -> void:
	assert_eq(_split("{ {\"a\": 1}[\"a\"] } and {\"}\"}"),
		[["([] {\"a\": 1} \"a\")", " and ", "\"}\""], []])


func test_errors() -> void:
	assert_eq(_split("oops }")[1], ["Unmatched '}' in text. Write '}}' for a literal brace."])
	assert_eq(_split("{open")[1], ["Unclosed '{' in text. Write '{{' for a literal brace."])
	assert_eq(_split("{}")[1], ["In '{}': Expected an expression between the braces."])
	assert_eq(_split("{1 +}")[1], ["In '{1 +}': Expected an expression, but the line ended."])


func test_parse_expression() -> void:
	assert_eq(TaleParser.parse_expression("a.b(1, c = 2)")["expr"].to_sexpr(), "(call (. a b) 1 c=2)")
	assert_eq(TaleParser.parse_expression("1 2")["error"], "Unexpected '2'.")


func _describe_tags(text: String) -> Array:
	var described := []
	for part in TaleText.split_interpolation(text)["parts"]:
		if part is Dictionary:
			described.append("%s:%s" % [part["tag"], part["expr"].to_sexpr()])
		else:
			described.append(part.to_sexpr() if part is TaleExpr else part)
	return described


func test_act_and_sound_tags_become_parts() -> void:
	assert_eq(_describe_tags("Look![act=shake(0.2)] Ow.[sound=bell]"),
		["Look!", "act:(call shake 0.2)", " Ow.", "sound:(call sound \"bell\")"])
	assert_eq(_describe_tags("[sound=\"door knock\"]"), ["sound:(call sound \"door knock\")"])
	assert_eq(_describe_tags("[act=give([1, 2], {\"a\": \"]\"})]x"),
		["act:(call give [1 2] {\"a\": \"]\"})", "x"])


func test_tag_errors() -> void:
	assert_eq(_split("[act=]")[1], ["In '[act=]': The tag needs a value, e.g. [act=shake(0.2)]."])
	assert_eq(_split("[act=shake(]")[1].size(), 1)
	assert_eq(_split("[act=shake(0.2)")[1], ["Unclosed '[act=' tag in text."])
	assert_eq(_split("[sound={name}]")[1], ["In '[sound={name}]': Write a sound name, or pick one with an expression in [act=sound(...)]."])


func test_typing_tag_checks() -> void:
	assert_eq(TaleText.check_typing_tags("[speed=2]fast[/speed] [instant]now[/instant] [pause] [pause=0.5]"), PackedStringArray())
	assert_eq(TaleText.check_typing_tags("[speed=0.5]open to the end"), PackedStringArray())
	assert_eq(TaleText.check_typing_tags("[speed={rate}] [pause={delay}]"), PackedStringArray(), "values from expressions are checked while playing")
	assert_eq(Array(TaleText.check_typing_tags("[speed=fast]")), ["[speed=fast] needs a number above 0, e.g. [speed=2] types twice as fast."])
	assert_eq(Array(TaleText.check_typing_tags("[speed]")), ["[speed=] needs a number above 0, e.g. [speed=2] types twice as fast."])
	assert_eq(Array(TaleText.check_typing_tags("[pause=soon]")), ["[pause=soon] needs a number of seconds, e.g. [pause=0.5]."])
	assert_eq(Array(TaleText.check_typing_tags("x[/instant]")), ["[/instant] has no [instant] before it."])
	assert_eq(Array(TaleText.check_typing_tags("[/pause]")), ["'[/pause]' is not a closing tag StoryTeller knows."])
	assert_eq(Array(TaleText.check_typing_tags("[instant=1]")), ["[instant] takes no value."])
	assert_eq(_split("Bad [speed=0] tag")[1], ["[speed=0] needs a number above 0, e.g. [speed=2] types twice as fast."], "reported with the text")

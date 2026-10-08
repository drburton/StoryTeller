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

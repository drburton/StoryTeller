class_name TaleToken
extends RefCounted
## A single token produced by [TaleLexer].

enum Type {
	IDENTIFIER,
	KEYWORD,
	INT,
	FLOAT,
	STRING,
	OPERATOR,
	ANNOTATION,
	COMMENT,
	NEWLINE,
	END,
	ERROR,
}

var type: Type
## Exact source text of the token.
var text: String
## Identifier, keyword, or operator text; the parsed value of a literal; the
## name of an annotation; the text of a comment after [code]#[/code]; or the
## message of an error token.
var value: Variant
## 1-based line where the token starts.
var line: int
## 1-based column where the token starts.
var column: int


func _init(p_type: Type, p_text: String, p_value: Variant, p_line: int, p_column: int) -> void:
	type = p_type
	text = p_text
	value = p_value
	line = p_line
	column = p_column


func is_op(op: String) -> bool:
	return type == Type.OPERATOR and value == op


func is_keyword(word: String) -> bool:
	return type == Type.KEYWORD and value == word


func _to_string() -> String:
	return "%s(%s)" % [Type.keys()[type], text.c_escape()]

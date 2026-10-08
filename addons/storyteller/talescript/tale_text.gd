class_name TaleText
extends RefCounted
## Helpers for the text of dialogue, narration, and choice options.


## Splits [param text] into literal pieces and [code]{expression}[/code]
## pieces. Returns a dictionary with:
## - [code]parts[/code]: Array of Strings (literal text) and TaleExpr (values to insert);
## - [code]errors[/code]: PackedStringArray of problems found.
## [code]{{[/code] and [code]}}[/code] stand for literal braces.
static func split_interpolation(text: String) -> Dictionary:
	var parts: Array = []
	var errors := PackedStringArray()
	var literal := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "{" and text.substr(i, 2) == "{{":
			literal += "{"
			i += 2
		elif c == "}" and text.substr(i, 2) == "}}":
			literal += "}"
			i += 2
		elif c == "}":
			errors.append("Unmatched '}' in text. Write '}}' for a literal brace.")
			literal += c
			i += 1
		elif c == "{":
			var end := _find_closing_brace(text, i)
			if end == -1:
				errors.append("Unclosed '{' in text. Write '{{' for a literal brace.")
				literal += text.substr(i)
				break
			if not literal.is_empty():
				parts.append(literal)
				literal = ""
			var source := text.substr(i + 1, end - i - 1)
			var parsed := TaleParser.parse_expression(source)
			if parsed["error"]:
				errors.append("In '{%s}': %s" % [source, parsed["error"]])
			else:
				parts.append(parsed["expr"])
			i = end + 1
		else:
			literal += c
			i += 1
	if not literal.is_empty():
		parts.append(literal)
	return {"parts": parts, "errors": errors}


## Index of the '}' that closes the '{' at [param open], skipping nested
## braces and quoted strings, or -1.
static func _find_closing_brace(text: String, open: int) -> int:
	var depth := 0
	var quote := ""
	var i := open
	while i < text.length():
		var c := text[i]
		if not quote.is_empty():
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return i
		i += 1
	return -1

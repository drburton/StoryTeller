class_name TaleText
extends RefCounted
## Helpers for the text of dialogue, narration, and choice options.


## Splits [param text] into literal pieces, [code]{expression}[/code]
## pieces, and tags that run something at a point in the text. Returns a
## dictionary with:
## - [code]parts[/code]: Array of Strings (literal text), TaleExpr (values to
##   insert), and Dictionaries [code]{"tag": "act" or "sound", "expr": TaleExpr}[/code]
##   for [code][act=...][/code] and [code][sound=...][/code] tags;
## - [code]errors[/code]: PackedStringArray of problems found.
## [code]{{[/code] and [code]}}[/code] stand for literal braces.
## [code][sound=bell][/code] becomes the call [code]sound("bell")[/code].
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
		elif c == "[" and (text.substr(i, 5) == "[act=" or text.substr(i, 7) == "[sound="):
			var tag := "act" if text.substr(i, 5) == "[act=" else "sound"
			var end := _find_closing_bracket(text, i)
			if end == -1:
				errors.append("Unclosed '[%s=' tag in text." % tag)
				literal += text.substr(i)
				break
			var value := text.substr(i + tag.length() + 2, end - i - tag.length() - 2).strip_edges()
			var parsed := _parse_tag_value(tag, value)
			if parsed["error"]:
				errors.append("In '[%s=%s]': %s" % [tag, value, parsed["error"]])
			else:
				if not literal.is_empty():
					parts.append(literal)
					literal = ""
				parts.append({"tag": tag, "expr": parsed["expr"]})
			i = end + 1
		else:
			literal += c
			i += 1
	if not literal.is_empty():
		parts.append(literal)
	errors.append_array(check_typing_tags(text))
	return {"parts": parts, "errors": errors}


## Problems with the typing tags in [param text]: [code][pause=...][/code]
## and [code][speed=...][/code] values that are not numbers, and closing tags
## without an opening one.
static func check_typing_tags(text: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var regex := RegEx.create_from_string("\\[(/?)(pause|speed|instant)(?:=([^\\]]*))?\\]")
	var open := {"speed": 0, "instant": 0}
	for found in regex.search_all(text):
		var closing := found.get_string(1) == "/"
		var tag := found.get_string(2)
		var value := found.get_string(3)
		var has_value := found.get_start(3) != -1
		# A value from {expression} is only known while the story plays.
		var computed := value.contains("{")
		if closing:
			if tag == "pause" or has_value:
				errors.append("'%s' is not a closing tag StoryTeller knows." % found.get_string())
			elif open[tag] == 0:
				errors.append("[/%s] has no [%s] before it." % [tag, tag])
			else:
				open[tag] -= 1
			continue
		match tag:
			"pause":
				if has_value and not computed and not (value.is_valid_float() and value.to_float() >= 0.0):
					errors.append("[pause=%s] needs a number of seconds, e.g. [pause=0.5]." % value)
			"speed":
				if not computed and not (has_value and value.is_valid_float() and value.to_float() > 0.0):
					errors.append("[speed=%s] needs a number above 0, e.g. [speed=2] types twice as fast." % value)
				open["speed"] += 1
			"instant":
				if has_value:
					errors.append("[instant] takes no value.")
				open["instant"] += 1
	return errors


static func _parse_tag_value(tag: String, value: String) -> Dictionary:
	if value.is_empty():
		var example := "[act=shake(0.2)]" if tag == "act" else "[sound=bell]"
		return {"error": "The tag needs a value, e.g. %s." % example, "expr": null}
	if tag == "act":
		return TaleParser.parse_expression(value)
	var sound_name := value
	if sound_name.length() >= 2 and sound_name[0] in ["\"", "'"] and sound_name.ends_with(sound_name[0]):
		sound_name = sound_name.substr(1, sound_name.length() - 2)
	if sound_name.contains("{") or sound_name.contains("\"") or sound_name.contains("'"):
		return {"error": "Write a sound name, or pick one with an expression in [act=sound(...)].", "expr": null}
	return TaleParser.parse_expression("sound(\"%s\")" % sound_name.c_escape())


## Index of the ']' that closes the '[' at [param open], skipping nested
## brackets and quoted strings, or -1.
static func _find_closing_bracket(text: String, open: int) -> int:
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
		elif c == "[":
			depth += 1
		elif c == "]":
			depth -= 1
			if depth == 0:
				return i
		i += 1
	return -1


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

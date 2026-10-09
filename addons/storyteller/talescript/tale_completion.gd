class_name TaleCompletion
extends RefCounted
## Autocomplete suggestions for TaleScript, used by the Story editor.
##
## [method suggest] looks at the text before the caret and returns what fits
## there: annotations after [code]@[/code], beats after [code]jump[/code],
## members after [code]cast.[/code] or [code]camera.[/code], moods after
## [code]cast ([/code], and otherwise keywords, actions, cast members,
## variables, and functions.

enum Kind { KEYWORD, ACTION, CAST, MOOD, BEAT, TALE, VARIABLE, FUNCTION, CONSTANT, MEMBER, ANNOTATION }

const ANNOTATIONS: Array[String] = ["global", "id", "no_rewind", "once", "show_disabled", "skip_safe", "title", "voice"]
const STATEMENT_KEYWORDS: Array[String] = [
	"await", "break", "choose", "continue", "elif", "else", "for", "if", "jump",
	"match", "pass", "return", "var", "while",
]
const EXPRESSION_KEYWORDS: Array[String] = ["and", "await", "false", "in", "not", "null", "or", "true"]
const TOP_LEVEL_KEYWORDS: Array[String] = ["beat", "const", "var"]
const CAST_METHODS: Array[String] = ["animate", "enter", "exit", "hop", "move_to", "nod", "scale_to", "shake", "to_back", "to_front"]
const CAST_PROPERTIES: Array[String] = ["display_name", "draw_order", "flip", "mood", "on_stage", "tint"]
const CAMERA_METHODS: Array[String] = ["pan", "reset", "rotate", "shake", "zoom"]
const CAMERA_PROPERTIES: Array[String] = ["angle", "offset", "zoom_level"]


## Suggestions for the caret at [param column] of [param line] (both from
## 0). Each is [code]{"kind": Kind, "text": String, "insert": String}[/code],
## sorted, and filtered by the word being typed.
static func suggest(source: String, line: int, column: int, context: TaleCheckContext) -> Array[Dictionary]:
	var lines := source.split("\n")
	if line < 0 or line >= lines.size():
		return []
	var before := lines[line].trim_suffix("\r").substr(0, column)
	var word := _trailing_word(before)
	var head := before.substr(0, before.length() - word.length())
	var found: Array[Dictionary] = []
	var doc := TaleParser.parse(source)

	var string_member := RegEx.create_from_string("([A-Za-z_]\\w*)\\.enter\\(\"$").search(head)
	if string_member != null and context.cast.has(string_member.get_string(1)):
		_add_all(found, context.cast[string_member.get_string(1)], Kind.MOOD)
		return _finish(found, word)
	if _inside_string(head):
		return []
	if head.ends_with("@"):
		_add_all(found, ANNOTATIONS, Kind.ANNOTATION)
		return _finish(found, word)

	var jump := RegEx.create_from_string("^\\s*jump\\s+(?:([A-Za-z_]\\w*)\\.)?$").search(head)
	if jump != null:
		var tale_name := jump.get_string(1)
		if tale_name.is_empty():
			_add_all(found, _beats(doc), Kind.BEAT)
			for other in context.tales:
				found.append({"kind": Kind.TALE, "text": other, "insert": other + "."})
		elif context.tales.has(tale_name):
			_add_all(found, context.tales[tale_name]["beats"], Kind.BEAT)
		return _finish(found, word)

	var member := RegEx.create_from_string("([A-Za-z_]\\w*)\\.$").search(head)
	if member != null:
		var owner := member.get_string(1)
		if context.cast.has(owner):
			_add_calls(found, CAST_METHODS, Kind.MEMBER)
			_add_all(found, CAST_PROPERTIES, Kind.MEMBER)
		elif owner == "camera":
			_add_calls(found, CAMERA_METHODS, Kind.MEMBER)
			_add_all(found, CAMERA_PROPERTIES, Kind.MEMBER)
		elif context.tales.has(owner):
			_add_all(found, context.tales[owner]["beats"], Kind.BEAT)
			_add_all(found, context.tales[owner]["vars"], Kind.VARIABLE)
		return _finish(found, word)

	var mood := RegEx.create_from_string("^\\s*([A-Za-z_]\\w*)\\s*\\($").search(head)
	if mood != null and context.cast.has(mood.get_string(1)):
		_add_all(found, context.cast[mood.get_string(1)], Kind.MOOD)
		return _finish(found, word)

	var at_line_start := head.strip_edges().is_empty()
	if at_line_start and head.is_empty():
		_add_all(found, TOP_LEVEL_KEYWORDS, Kind.KEYWORD)
		return _finish(found, word)
	if at_line_start:
		_add_all(found, STATEMENT_KEYWORDS, Kind.KEYWORD)
		_add_calls(found, _beats(doc), Kind.BEAT)
	else:
		_add_all(found, EXPRESSION_KEYWORDS, Kind.KEYWORD)
	for action_name in context.actions:
		found.append({"kind": Kind.ACTION, "text": action_name, "insert": action_name + "("})
	_add_all(found, context.cast.keys(), Kind.CAST)
	_add_all(found, context.exposed.keys(), Kind.VARIABLE)
	_add_all(found, _variables(doc), Kind.VARIABLE)
	if not at_line_start:
		_add_calls(found, TaleCheckContext.BUILTIN_FUNCTIONS, Kind.FUNCTION)
		_add_all(found, TaleCheckContext.BUILTIN_CONSTANTS, Kind.CONSTANT)
		_add_calls(found, TaleCheckContext.CONSTRUCTORS, Kind.FUNCTION)
		_add_all(found, context.tales.keys(), Kind.TALE)
	return _finish(found, word)


static func _trailing_word(text: String) -> String:
	var i := text.length()
	while i > 0 and (text[i - 1] == "_" or text[i - 1].is_valid_identifier() or text[i - 1].is_valid_int()):
		i -= 1
	return text.substr(i)


## True if [param text] ends inside a quoted string.
static func _inside_string(text: String) -> bool:
	var quote := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if not quote.is_empty():
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return true
		i += 1
	return not quote.is_empty()


static func _beats(doc: TaleDocument) -> PackedStringArray:
	var names := PackedStringArray()
	for statement in doc.statements:
		if statement.kind == TaleNode.Kind.BEAT and not statement.name.is_empty():
			names.append(statement.name)
	return names


## Variables declared anywhere in the tale, including inside beats.
static func _variables(doc: TaleDocument) -> PackedStringArray:
	var names := PackedStringArray()
	var pending: Array = doc.statements.duplicate()
	while not pending.is_empty():
		var node: TaleNode = pending.pop_back()
		if (node.kind == TaleNode.Kind.VAR or node.kind == TaleNode.Kind.CONST) and not node.name.is_empty() and node.name not in names:
			names.append(node.name)
		pending.append_array(node.body)
	return names


static func _add_all(found: Array[Dictionary], names: Variant, kind: Kind) -> void:
	for item in names:
		found.append({"kind": kind, "text": str(item), "insert": str(item)})


static func _add_calls(found: Array[Dictionary], names: Variant, kind: Kind) -> void:
	for item in names:
		found.append({"kind": kind, "text": str(item), "insert": str(item) + "("})


static func _finish(found: Array[Dictionary], word: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	var prefix := word.to_lower()
	for item in found:
		var key: String = item["text"]
		if seen.has(key) or not key.to_lower().begins_with(prefix) or key == word:
			continue
		seen[key] = true
		result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["text"].naturalnocasecmp_to(b["text"]) < 0)
	return result

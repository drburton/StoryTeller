@tool
class_name TaleSyntaxHighlighter
extends SyntaxHighlighter
## Colors TaleScript in a [CodeEdit]: keywords, strings, numbers, comments,
## annotations, beat names, speakers, and values and tags inside text.
##
## In the editor, colors follow the editor's script theme. Elsewhere, the
## defaults in [member palette] are used.

const KEYWORDS := TaleLexer.KEYWORDS
const _SPEAKER_PATTERN := "^\\s*(?:@\\w+(?:\\([^)]*\\))?\\s+)*([A-Za-z_][A-Za-z0-9_]*)\\s*(\\([^)]*\\))?\\s*:\\s*[\"']"

## Colors by role: text, keyword, string, number, comment, doc_comment,
## annotation, symbol, beat, speaker, interpolation, tag.
var palette := {
	"text": Color("cdcfd2"),
	"keyword": Color("ff7085"),
	"string": Color("ffeda1"),
	"number": Color("a1ffe0"),
	"comment": Color("cdcfd280"),
	"doc_comment": Color("99b3cccc"),
	"annotation": Color("ffb373"),
	"symbol": Color("abc9ff"),
	"beat": Color("57b3ff"),
	"speaker": Color("42ffc2"),
	"interpolation": Color("bce0ff"),
	"tag": Color("c792ea"),
}

var _speaker_regex := RegEx.create_from_string(_SPEAKER_PATTERN)
## Open triple quote at the start of each line ("" when outside a string).
var _line_states: Array[String] = []


## Uses the editor's script colors when running inside the editor.
func use_editor_theme() -> void:
	if not Engine.is_editor_hint():
		return
	var settings := EditorInterface.get_editor_settings()
	var prefix := "text_editor/theme/highlighting/"
	var mapping := {
		"text": "text_color",
		"keyword": "keyword_color",
		"string": "string_color",
		"number": "number_color",
		"comment": "comment_color",
		"doc_comment": "doc_comment_color",
		"symbol": "symbol_color",
		"beat": "function_color",
		"speaker": "base_type_color",
		"interpolation": "member_variable_color",
		"annotation": "gdscript/annotation_color",
		"tag": "gdscript/node_path_color",
	}
	for role in mapping:
		var setting: String = prefix + mapping[role]
		if settings.has_setting(setting):
			palette[role] = settings.get_setting(setting)


func _clear_highlighting_cache() -> void:
	_line_states.clear()


func _get_line_syntax_highlighting(line_index: int) -> Dictionary:
	var text_edit := get_text_edit()
	if _line_states.size() != text_edit.get_line_count():
		_compute_line_states(text_edit)
	return highlight_line(text_edit.get_line(line_index), _line_states[line_index])["colors"]


func _compute_line_states(text_edit: TextEdit) -> void:
	_line_states.clear()
	var state := ""
	for i in text_edit.get_line_count():
		_line_states.append(state)
		state = highlight_line(text_edit.get_line(i), state)["open_quote"]


## Highlights one line. [param open_quote] is the triple quote still open from
## earlier lines, or "". Returns {"colors": {column: {"color": Color}},
## "open_quote": triple quote still open at the end of the line, or ""}.
func highlight_line(text: String, open_quote := "") -> Dictionary:
	var colors := {}
	var i := 0
	var n := text.length()
	if not open_quote.is_empty():
		var close := text.find(open_quote)
		var end := n if close == -1 else close + 3
		_color_string(colors, text, 0, end)
		if close == -1:
			return {"colors": colors, "open_quote": open_quote}
		i = end

	var speaker := _speaker_regex.search(text)
	var previous_word := ""
	while i < n:
		var c := text[i]
		if c == " " or c == "\t":
			i += 1
		elif c == "#":
			colors[i] = {"color": palette["doc_comment"] if text.substr(i, 2) == "##" else palette["comment"]}
			break
		elif c == "@":
			var end := _word_end(text, i + 1)
			colors[i] = {"color": palette["annotation"]}
			i = end
		elif c == "\"" or c == "'":
			var quote := c.repeat(3) if text.substr(i, 3) == c.repeat(3) else c
			var close := text.find(quote, i + quote.length())
			while close != -1 and quote.length() == 1 and _is_escaped(text, close):
				close = text.find(quote, close + 1)
			var end := n if close == -1 else close + quote.length()
			_color_string(colors, text, i, end)
			if close == -1 and quote.length() == 3:
				return {"colors": colors, "open_quote": quote}
			i = end
			previous_word = ""
		elif TaleLexer._is_digit(c) or (c == "." and TaleLexer._is_digit(text.substr(i + 1, 1))):
			colors[i] = {"color": palette["number"]}
			i += 1
			while i < n and (TaleLexer._is_identifier_char(text[i]) or text[i] == "."):
				i += 1
		elif TaleLexer._is_identifier_start(c):
			var end := _word_end(text, i)
			var word := text.substr(i, end - i)
			var role := "text"
			if word in KEYWORDS:
				role = "keyword"
			elif previous_word in ["beat", "jump", "."] and _after_jump_or_beat(text, i):
				role = "beat"
			elif speaker != null and speaker.get_start(1) == i:
				role = "speaker"
			elif text.substr(end, 1) == "(":
				role = "beat"
			colors[i] = {"color": palette[role]}
			previous_word = word
			i = end
		else:
			colors[i] = {"color": palette["symbol"]}
			previous_word = c if c == "." else ""
			i += 1
			if i < n and not (text[i] in [" ", "\t"]):
				colors[i] = {"color": palette["text"]}
	return {"colors": colors, "open_quote": ""}


## Colors text[start, end) as a string, marking {values} and [tags].
func _color_string(colors: Dictionary, text: String, start: int, end: int) -> void:
	colors[start] = {"color": palette["string"]}
	var i := start
	while i < end:
		var c := text[i]
		if c == "{" and text.substr(i, 2) != "{{":
			var close := text.find("}", i)
			if close == -1 or close >= end:
				break
			colors[i] = {"color": palette["interpolation"]}
			colors[close + 1] = {"color": palette["string"]}
			i = close + 1
		elif c == "[":
			var close := text.find("]", i)
			if close == -1 or close >= end:
				break
			colors[i] = {"color": palette["tag"]}
			colors[close + 1] = {"color": palette["string"]}
			i = close + 1
		else:
			i += 2 if c == "{" else 1
	if end < text.length():
		colors[end] = {"color": palette["text"]}


## True when the word at [param start] follows "beat", "jump", or a "."
## that itself follows a jump target, as in "jump other.start".
func _after_jump_or_beat(text: String, start: int) -> bool:
	var before := text.substr(0, start).strip_edges()
	return before.ends_with("beat") or before.ends_with("jump") \
		or RegEx.create_from_string("jump\\s+\\w+\\.$").search(before) != null


static func _word_end(text: String, start: int) -> int:
	var i := start
	while i < text.length() and TaleLexer._is_identifier_char(text[i]):
		i += 1
	return i


static func _is_escaped(text: String, index: int) -> bool:
	var backslashes := 0
	var i := index - 1
	while i >= 0 and text[i] == "\\":
		backslashes += 1
		i -= 1
	return backslashes % 2 == 1

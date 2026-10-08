class_name TaleLexer
extends RefCounted
## Splits TaleScript source into tokens.
##
## A NEWLINE token ends every logical line, including blank and comment-only
## lines. Line breaks inside brackets, after a backslash, or inside
## triple-quoted strings do not end a logical line. Problems are recorded in
## [member diagnostics] and produce ERROR tokens; the lexer never stops early.
##
## Lines inside brackets must be indented deeper than the line that opened the
## bracket, unless they start with a closing bracket. A line that breaks this
## rule ends the bracket early with an error, so one missing ')' cannot hide
## the rest of the file.

const KEYWORDS: Array[String] = [
	"and", "await", "beat", "break", "choose", "const", "continue", "elif",
	"else", "false", "for", "if", "in", "jump", "match", "not", "null", "or",
	"pass", "return", "true", "var", "when", "while",
]

## Longest operators first, so the first match is the longest one.
const OPERATORS: Array[String] = [
	"**=", "<<=", ">>=",
	"**", "==", "!=", "<=", ">=", "&&", "||", "+=", "-=", "*=", "/=", "%=",
	"&=", "|=", "^=", ":=", "->", "<<", ">>",
	"+", "-", "*", "/", "%", "<", ">", "=", "!", "&", "|", "^", "~",
	"(", ")", "[", "]", "{", "}", ",", ":", ".",
]

const _OPENERS := ["(", "[", "{"]
const _CLOSERS := [")", "]", "}"]
const _ESCAPES := {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", "\"": "\"", "'": "'"}

var diagnostics: Array[TaleDiagnostic] = []

var _src := ""
var _pos := 0
var _line := 1
var _line_start := 0
var _brackets: Array[TaleToken] = []
## Indentation width of the line where the outermost open bracket started.
var _bracket_line_indent := 0
var _tokens: Array[TaleToken] = []


## Returns the tokens of [param source], always ending with an END token.
func tokenize(source: String) -> Array[TaleToken]:
	_src = source
	_pos = 0
	_line = 1
	_line_start = 0
	_brackets.clear()
	_tokens = []
	diagnostics.clear()

	var length := _src.length()
	while _pos < length:
		var c := _src[_pos]
		if c == " " or c == "\t" or c == "\r":
			_pos += 1
		elif c == "\n":
			if not _brackets.is_empty() and _next_line_leaves_brackets():
				_close_brackets_with_error()
			if _brackets.is_empty():
				_tokens.append(TaleToken.new(TaleToken.Type.NEWLINE, "\n", "\n", _line, _column(_pos)))
			_pos += 1
			_new_line()
		elif c == "#":
			_comment()
		elif c == "\\":
			_continuation()
		elif c == "\"" or c == "'":
			_string()
		elif c == "@":
			_annotation()
		elif _is_digit(c) or (c == "." and _is_digit(_char_at(_pos + 1))):
			_number()
		elif _is_identifier_start(c):
			_identifier()
		else:
			_operator()

	_close_brackets_with_error()
	_tokens.append(TaleToken.new(TaleToken.Type.END, "", null, _line, _column(_pos)))
	return _tokens


func _new_line() -> void:
	_line += 1
	_line_start = _pos


func _column(offset: int) -> int:
	return offset - _line_start + 1


func _char_at(offset: int) -> String:
	return _src[offset] if offset < _src.length() else ""


func _comment() -> void:
	var start := _pos
	while _pos < _src.length() and _src[_pos] != "\n":
		_pos += 1
	var text := _src.substr(start, _pos - start).trim_suffix("\r")
	_tokens.append(TaleToken.new(TaleToken.Type.COMMENT, text, text.substr(1), _line, _column(start)))


func _continuation() -> void:
	var next := _pos + 1
	if _char_at(next) == "\r":
		next += 1
	if _char_at(next) == "\n":
		_pos = next + 1
		_new_line()
	else:
		_add_error("\\", "A backslash must be the last character on the line.", _pos)
		_pos += 1


func _string() -> void:
	var start := _pos
	var start_line := _line
	var start_column := _column(_pos)
	var quote := _src[_pos]
	var triple := _src.substr(_pos, 3) == quote.repeat(3)
	_pos += 3 if triple else 1
	var value := ""
	var closed := false
	while _pos < _src.length():
		var c := _src[_pos]
		if triple and _src.substr(_pos, 3) == quote.repeat(3):
			_pos += 3
			closed = true
			break
		if not triple and c == quote:
			_pos += 1
			closed = true
			break
		if c == "\n":
			if not triple:
				break
			value += c
			_pos += 1
			_new_line()
		elif c == "\\":
			value += _escape()
		else:
			value += c
			_pos += 1
	var text := _src.substr(start, _pos - start)
	if not closed:
		_error_at("Unterminated string.", start_line, start_column)
		_tokens.append(TaleToken.new(TaleToken.Type.ERROR, text, "Unterminated string.", start_line, start_column))
		return
	_tokens.append(TaleToken.new(TaleToken.Type.STRING, text, value, start_line, start_column))


## Reads an escape sequence at the current backslash and returns its value.
func _escape() -> String:
	var start := _pos
	var c := _char_at(_pos + 1)
	if _ESCAPES.has(c):
		_pos += 2
		return _ESCAPES[c]
	if c == "u" or c == "U":
		var digits := 4 if c == "u" else 6
		var hex := _src.substr(_pos + 2, digits)
		if hex.length() == digits and hex.is_valid_hex_number():
			_pos += 2 + digits
			return String.chr(hex.hex_to_int())
		_error_at("Invalid unicode escape.", _line, _column(start))
		_pos += 2
		return ""
	if c == "\n" or (c == "\r" and _char_at(_pos + 2) == "\n"):
		# A backslash before a line break joins the lines.
		_pos += 3 if c == "\r" else 2
		_new_line()
		return ""
	_error_at("Unknown escape sequence '\\%s'." % c, _line, _column(start))
	_pos += 2 if c != "" else 1
	return c


func _annotation() -> void:
	var start := _pos
	_pos += 1
	while _pos < _src.length() and _is_identifier_char(_src[_pos]):
		_pos += 1
	var text := _src.substr(start, _pos - start)
	if text.length() == 1:
		_add_error(text, "Expected an annotation name after '@'.", start)
		return
	_tokens.append(TaleToken.new(TaleToken.Type.ANNOTATION, text, text.substr(1), _line, _column(start)))


func _number() -> void:
	var start := _pos
	var is_float := false
	var base_prefix := _src.substr(_pos, 2).to_lower()
	if base_prefix == "0x" or base_prefix == "0b":
		_pos += 2
		var digits_start := _pos
		var valid := "0123456789abcdefABCDEF_" if base_prefix == "0x" else "01_"
		while _pos < _src.length() and valid.contains(_src[_pos]):
			_pos += 1
		var text := _src.substr(start, _pos - start)
		var digits := _src.substr(digits_start, _pos - digits_start).replace("_", "")
		if digits.is_empty():
			_add_error(text, "Expected digits after '%s'." % base_prefix, start)
			return
		var number := digits.hex_to_int() if base_prefix == "0x" else digits.bin_to_int()
		_tokens.append(TaleToken.new(TaleToken.Type.INT, text, number, _line, _column(start)))
		return

	_skip_digits()
	if _char_at(_pos) == "." and _is_digit(_char_at(_pos + 1)):
		is_float = true
		_pos += 1
		_skip_digits()
	var e := _char_at(_pos)
	if e == "e" or e == "E":
		var sign := _char_at(_pos + 1)
		var exponent_start := _pos + (2 if sign == "+" or sign == "-" else 1)
		if _is_digit(_char_at(exponent_start)):
			is_float = true
			_pos = exponent_start
			_skip_digits()
	var number_text := _src.substr(start, _pos - start)
	var clean := number_text.replace("_", "")
	if is_float:
		_tokens.append(TaleToken.new(TaleToken.Type.FLOAT, number_text, clean.to_float(), _line, _column(start)))
	else:
		_tokens.append(TaleToken.new(TaleToken.Type.INT, number_text, clean.to_int(), _line, _column(start)))


func _skip_digits() -> void:
	while _pos < _src.length() and (_is_digit(_src[_pos]) or _src[_pos] == "_"):
		_pos += 1


func _identifier() -> void:
	var start := _pos
	while _pos < _src.length() and _is_identifier_char(_src[_pos]):
		_pos += 1
	var text := _src.substr(start, _pos - start)
	var type := TaleToken.Type.KEYWORD if text in KEYWORDS else TaleToken.Type.IDENTIFIER
	_tokens.append(TaleToken.new(type, text, text, _line, _column(start)))


func _operator() -> void:
	for op in OPERATORS:
		if _src.substr(_pos, op.length()) == op:
			var token := TaleToken.new(TaleToken.Type.OPERATOR, op, op, _line, _column(_pos))
			_tokens.append(token)
			_pos += op.length()
			_track_bracket(token)
			return
	var c := _src[_pos]
	var message := "Unexpected character '%s'." % c
	if c == ";":
		message = "TaleScript does not use ';'. Put each statement on its own line."
	_add_error(c, message, _pos)
	_pos += 1


func _track_bracket(token: TaleToken) -> void:
	if token.text in _OPENERS:
		if _brackets.is_empty():
			_bracket_line_indent = _indent_width(_line_start)
		_brackets.append(token)
	elif token.text in _CLOSERS:
		var expected_opener: String = _OPENERS[_CLOSERS.find(token.text)]
		if _brackets.is_empty() or _brackets.back().text != expected_opener:
			_error_at("'%s' does not match any opening bracket." % token.text, token.line, token.column)
		else:
			_brackets.pop_back()


## Called at a line break inside brackets. True when the next non-blank line is
## not indented deeper than the line that opened the brackets.
func _next_line_leaves_brackets() -> bool:
	var start := _pos + 1
	while start < _src.length():
		var end := _src.find("\n", start)
		if end == -1:
			end = _src.length()
		var content := _src.substr(start, end - start).strip_edges()
		if not content.is_empty() and not content.begins_with("#"):
			if content[0] in _CLOSERS:
				return false
			return _indent_width(start) <= _bracket_line_indent
		start = end + 1
	return false


func _close_brackets_with_error() -> void:
	for opener in _brackets:
		_error_at("'%s' is never closed." % opener.text, opener.line, opener.column)
		_tokens.append(TaleToken.new(TaleToken.Type.ERROR, "", "'%s' is never closed." % opener.text, opener.line, opener.column))
	_brackets.clear()


func _indent_width(line_start: int) -> int:
	var i := line_start
	while i < _src.length() and (_src[i] == " " or _src[i] == "\t"):
		i += 1
	return i - line_start


func _add_error(text: String, message: String, offset: int) -> void:
	_error_at(message, _line, _column(offset))
	_tokens.append(TaleToken.new(TaleToken.Type.ERROR, text, message, _line, _column(offset)))


func _error_at(message: String, line: int, column: int) -> void:
	diagnostics.append(TaleDiagnostic.new(TaleDiagnostic.Severity.ERROR, message, line, column))


static func _is_digit(c: String) -> bool:
	return c.length() == 1 and c >= "0" and c <= "9"


static func _is_identifier_start(c: String) -> bool:
	if c.is_empty():
		return false
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or c.unicode_at(0) > 127


static func _is_identifier_char(c: String) -> bool:
	return _is_identifier_start(c) or _is_digit(c)

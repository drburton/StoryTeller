class_name YarnConverter
extends RefCounted
## Converts a Yarn Spinner script (a [code].yarn[/code] file, an open
## dialogue format) into TaleScript, so writers can bring existing dialogue
## into StoryTeller. Each Yarn node becomes a beat.
## [codeblock]
## var result := YarnConverter.to_tale(FileAccess.get_file_as_string("res://intro.yarn"), "intro")
## result["text"]    # the tale's TaleScript
## result["notes"]   # what could not be converted exactly, with Yarn line numbers
## [/codeblock]
##
## Converted: node titles, dialogue and narration, [code]{$variable}[/code]
## values, shortcut options ([code]->[/code]) with conditions and nested
## bodies, [code]<<if>>[/code] chains, [code]<<set>>[/code],
## [code]<<declare>>[/code], [code]<<jump>>[/code], [code]<<detour>>[/code],
## [code]<<return>>[/code], [code]<<stop>>[/code], [code]<<wait>>[/code],
## [code]#line:[/code] ids, and the [code]visited()[/code],
## [code]random()[/code], [code]random_range()[/code], and
## [code]dice()[/code] functions. Anything else is kept as a comment and
## listed in the notes.

const KEYWORDS: Array[String] = [
	"and", "await", "beat", "break", "choose", "const", "continue", "elif", "else",
	"false", "for", "if", "in", "jump", "match", "not", "null", "or", "pass",
	"return", "timeout", "true", "var", "while",
]
## Yarn's word operators and their TaleScript spelling.
const WORD_OPERATORS := {
	"is": "==", "eq": "==", "neq": "!=", "gt": ">", "lt": "<", "gte": ">=",
	"lte": "<=", "and": "and", "or": "or", "not": "not", "xor": "!=",
}
const SYMBOL_OPERATORS := {"&&": "and", "||": "or", "!": "not "}

var _tale_name := ""
var _cast_ids := PackedStringArray()
## Yarn node title to beat name.
var _beats: Dictionary = {}
## Variable name to [value source, declared].
var _variables: Dictionary = {}
## Speaker name in Yarn to the TaleScript name used for it.
var _speakers: Dictionary = {}
## Speakers that need a [code]const[/code] because they are not cast members.
var _speaker_consts: Dictionary = {}
var _notes := PackedStringArray()
var _used_ids: Dictionary = {}


## Converts [param source], a whole Yarn file, into the TaleScript of a tale
## called [param tale_name]. Speakers whose name matches an id in
## [param cast_ids] (compared in snake_case) speak as those cast members;
## others become constants holding their name. Returns
## [code]{"text": String, "notes": PackedStringArray, "beats": Dictionary}[/code],
## where beats maps each Yarn node title to its beat.
static func to_tale(source: String, tale_name := "", cast_ids := PackedStringArray()) -> Dictionary:
	var converter := YarnConverter.new()
	converter._tale_name = tale_name
	converter._cast_ids = cast_ids
	return converter._convert(source)


## Converts the Yarn file at [param yarn_path] and writes it as a tale in
## [param tales_folder], named after the Yarn file. An existing tale is not
## overwritten. Returns [code]{"path": String, "notes": PackedStringArray,
## "error": String}[/code]; error is "" on success.
static func import_file(yarn_path: String, tales_folder: String, cast_ids := PackedStringArray()) -> Dictionary:
	var tale_name := _identifier(yarn_path.get_file().get_basename())
	var path := tales_folder.path_join(tale_name + ".tale")
	var result := {"path": path, "notes": PackedStringArray(), "error": ""}
	if not FileAccess.file_exists(yarn_path):
		result["error"] = "There is no file %s." % yarn_path
		return result
	if FileAccess.file_exists(path):
		result["error"] = "%s already exists; rename or remove it first." % path
		return result
	var converted := to_tale(FileAccess.get_file_as_string(yarn_path), tale_name, cast_ids)
	DirAccess.make_dir_recursive_absolute(tales_folder)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		result["error"] = "Can't write %s." % path
		return result
	file.store_string(converted["text"])
	file.close()
	result["notes"] = converted["notes"]
	return result


func _convert(source: String) -> Dictionary:
	var nodes := _split_nodes(source.replace("\r\n", "\n"))
	for node in nodes:
		var beat := _identifier(node["title"])
		while beat in _beats.values():
			beat += "_2"
		_beats[node["title"]] = beat
	var beat_texts := PackedStringArray()
	for node in nodes:
		var out := PackedStringArray()
		var lines := _body_lines(node)
		var parsed := _parse_block(lines, 0, 0)
		_emit_block(parsed["items"], 1, out)
		if out.is_empty():
			out.append("\tpass")
		var header := "beat %s:" % _beats[node["title"]]
		if node["title"] != _beats[node["title"]]:
			header = "@heading(%s)\n%s" % [TaleExpr.quote(node["title"]), header]
		beat_texts.append(header + "\n" + "\n".join(out))
	var top := PackedStringArray()
	top.append("## Converted from Yarn Spinner by StoryTeller.")
	var speaker_names := _speaker_consts.keys()
	speaker_names.sort()
	for const_name in speaker_names:
		top.append("const %s := %s" % [const_name, TaleExpr.quote(_speaker_consts[const_name])])
	var variable_names := _variables.keys()
	variable_names.sort()
	for variable in variable_names:
		var info: Array = _variables[variable]
		if not info[1]:
			_notes.append("$%s is never declared; it starts as %s." % [variable, info[0]])
		top.append("var %s := %s" % [variable, info[0]])
	var text := "\n".join(top) + "\n\n" + "\n\n".join(beat_texts) + "\n"
	return {"text": text, "notes": _notes, "beats": _beats}


# --- Nodes ----------------------------------------------------------------------

## Splits a Yarn file into nodes: [code]{"title", "line", "body": [[line number, text]]}[/code].
func _split_nodes(source: String) -> Array:
	var nodes := []
	var node := {}
	var in_body := false
	var lines := source.split("\n")
	for i in lines.size():
		var text: String = lines[i]
		var stripped := text.strip_edges()
		if not in_body:
			if stripped == "---":
				in_body = true
				if not node.has("title"):
					node["title"] = "node_%d" % (nodes.size() + 1)
					_notes.append("Line %d: a node has no title; it is called %s." % [i + 1, node["title"]])
				node["body"] = []
				node["line"] = i + 1
			elif stripped.contains(":"):
				var key := stripped.get_slice(":", 0).strip_edges()
				if key == "title":
					node["title"] = stripped.substr(stripped.find(":") + 1).strip_edges()
			continue
		if stripped == "===":
			nodes.append(node)
			node = {}
			in_body = false
			continue
		node["body"].append([i + 1, text])
	if in_body:
		nodes.append(node)
		_notes.append("The last node has no closing ===.")
	return nodes


## The non-empty lines of a node without comments, as
## [code]{"line", "indent", "text"}[/code].
func _body_lines(node: Dictionary) -> Array:
	var result := []
	for pair in node["body"]:
		var raw: String = pair[1]
		var text := _strip_comment(raw)
		if text.strip_edges().is_empty():
			continue
		var indent := 0
		for character in raw:
			if character == " ":
				indent += 1
			elif character == "\t":
				indent += 4
			else:
				break
		result.append({"line": pair[0], "indent": indent, "text": text.strip_edges()})
	return result


static func _strip_comment(text: String) -> String:
	var in_string := false
	for i in text.length():
		var character := text[i]
		if character == "\\":
			continue
		if character == "\"" and (i == 0 or text[i - 1] != "\\"):
			in_string = not in_string
		if not in_string and character == "/" and i + 1 < text.length() and text[i + 1] == "/" and (i == 0 or text[i - 1] != ":"):
			return text.substr(0, i)
	return text


# --- Parsing ----------------------------------------------------------------------

## Parses lines from [param start] while they are indented at least
## [param min_indent], stopping at [code]<<elseif>>[/code],
## [code]<<else>>[/code], and [code]<<endif>>[/code]. Returns
## [code]{"items": Array, "next": int}[/code].
func _parse_block(lines: Array, start: int, min_indent: int) -> Dictionary:
	var items := []
	var i := start
	while i < lines.size():
		var line: Dictionary = lines[i]
		if line["indent"] < min_indent:
			break
		var command := _command_of(line["text"])
		if command.begins_with("elseif ") or command == "else" or command == "endif":
			break
		if line["text"].begins_with("->"):
			var group := []
			var indent: int = line["indent"]
			while i < lines.size() and lines[i]["indent"] == indent and lines[i]["text"].begins_with("->"):
				var option: Dictionary = lines[i]
				var body := _parse_block(lines, i + 1, indent + 1)
				group.append({"line": option, "items": body["items"]})
				i = body["next"]
			items.append({"kind": "options", "options": group})
			continue
		if command.begins_with("if "):
			var chain := []
			var condition := command.substr(3)
			var keyword := "if"
			i += 1
			while true:
				var body := _parse_block(lines, i, min_indent)
				chain.append({"keyword": keyword, "condition": condition, "line": line["line"], "items": body["items"]})
				i = body["next"]
				if i >= lines.size():
					_notes.append("Line %d: <<if>> has no <<endif>>." % line["line"])
					break
				var next := _command_of(lines[i]["text"])
				i += 1
				if next == "endif":
					break
				if next == "else":
					keyword = "else"
					condition = ""
				elif next.begins_with("elseif "):
					keyword = "elif"
					condition = next.substr(7)
			items.append({"kind": "if", "chain": chain})
			continue
		items.append({"kind": "line", "line": line})
		i += 1
	return {"items": items, "next": i}


## The text inside [code]<<...>>[/code] when the whole line is one command,
## or "".
static func _command_of(text: String) -> String:
	var bare := _strip_tags(text)
	if bare.begins_with("<<") and bare.ends_with(">>") and bare.count("<<") == 1:
		return bare.substr(2, bare.length() - 4).strip_edges()
	return ""


# --- Writing ------------------------------------------------------------------------

func _emit_block(items: Array, depth: int, out: PackedStringArray) -> void:
	var indent := "\t".repeat(depth)
	var start := out.size()
	for item in items:
		match item["kind"]:
			"line":
				_emit_line(item["line"], indent, out)
			"if":
				for branch in item["chain"]:
					if branch["keyword"] == "else":
						out.append(indent + "else:")
					else:
						out.append("%s%s %s:" % [indent, branch["keyword"], _expression(branch["condition"], branch["line"])])
					var before := out.size()
					_emit_block(branch["items"], depth + 1, out)
					if out.size() == before:
						out.append(indent + "\tpass")
			"options":
				out.append(indent + "choose:")
				for option in item["options"]:
					_emit_option(option, depth + 1, out)
	if out.size() == start and depth > 0 and not items.is_empty():
		out.append(indent + "pass")


func _emit_option(option: Dictionary, depth: int, out: PackedStringArray) -> void:
	var indent := "\t".repeat(depth)
	var line: Dictionary = option["line"]
	var text: String = line["text"].substr(2).strip_edges()
	var tags := _tags_of(text)
	text = _strip_tags(text)
	var condition := ""
	var condition_at := text.find("<<if ")
	if condition_at >= 0 and text.ends_with(">>"):
		condition = text.substr(condition_at + 5, text.length() - condition_at - 7).strip_edges()
		text = text.substr(0, condition_at).strip_edges()
	elif text.contains("<<"):
		_notes.append("Line %d: only <<if>> is converted after an option; the rest is kept in its text." % line["line"])
	var prefix := _id_prefix(tags, line["line"])
	var header := "%s%s%s" % [indent, prefix, TaleExpr.quote(_text(text, line["line"]))]
	if not condition.is_empty():
		header += " if " + _expression(condition, line["line"])
	out.append(header + ":")
	var before := out.size()
	_emit_block(option["items"], depth + 1, out)
	if out.size() == before:
		out.append(indent + "\tpass")


func _emit_line(line: Dictionary, indent: String, out: PackedStringArray) -> void:
	var text: String = line["text"]
	var command := _command_of(text)
	if not command.is_empty() or text.begins_with("<<"):
		_emit_command(command, line, indent, out)
		return
	var tags := _tags_of(text)
	text = _strip_tags(text)
	var prefix := _id_prefix(tags, line["line"])
	var speaker := ""
	var colon := _speaker_colon(text)
	if colon > 0:
		speaker = _speaker(text.substr(0, colon).strip_edges())
		text = text.substr(colon + 1).strip_edges()
	var quoted := TaleExpr.quote(_text(text, line["line"]))
	out.append(indent + prefix + ("%s: %s" % [speaker, quoted] if not speaker.is_empty() else quoted))


func _emit_command(command: String, line: Dictionary, indent: String, out: PackedStringArray) -> void:
	var words := command.split(" ", false)
	var verb: String = words[0] if not words.is_empty() else ""
	var rest := command.substr(verb.length()).strip_edges()
	match verb:
		"set":
			var assign := _split_assignment(rest)
			if assign.is_empty():
				_unconverted(command, line, indent, out)
				return
			var variable := _variable_name(assign[0])
			var value := _expression(assign[1], line["line"])
			_note_variable(variable, value, false)
			out.append("%s%s = %s" % [indent, variable, value])
		"declare":
			var declared := _split_assignment(rest.get_slice(" as ", 0))
			if declared.is_empty():
				_unconverted(command, line, indent, out)
				return
			_note_variable(_variable_name(declared[0]), _expression(declared[1], line["line"]), true)
		"jump", "detour":
			if rest.begins_with("{"):
				_unconverted(command, line, indent, out)
				return
			if not _beats.has(rest):
				_notes.append("Line %d: there is no node '%s' to %s to." % [line["line"], rest, verb])
			var beat: String = _beats.get(rest, _identifier(rest))
			out.append(indent + ("jump %s" % beat if verb == "jump" else "%s()" % beat))
		"return", "stop":
			out.append(indent + "return")
		"wait":
			out.append("%swait(%s)" % [indent, _expression(rest, line["line"])])
		_:
			_unconverted(command if not command.is_empty() else line["text"], line, indent, out)


func _unconverted(command: String, line: Dictionary, indent: String, out: PackedStringArray) -> void:
	_notes.append("Line %d: <<%s>> was not converted; it is kept as a comment." % [line["line"], command])
	out.append("%s# Yarn: <<%s>>" % [indent, command])


# --- Text and expressions ---------------------------------------------------------

## Converts the text of a line: [code]{$x}[/code] becomes [code]{x}[/code],
## Yarn escapes become TaleScript ones.
func _text(text: String, line_number: int) -> String:
	var result := ""
	var i := 0
	while i < text.length():
		var character := text[i]
		if character == "\\" and i + 1 < text.length():
			var escaped := text[i + 1]
			match escaped:
				"{":
					result += "{{"
				"}":
					result += "}}"
				"[":
					result += "[lb]"
				"]":
					result += "[rb]"
				_:
					result += escaped
			i += 2
			continue
		if character == "{":
			var close := text.find("}", i)
			if close < 0:
				result += "{{"
				i += 1
				continue
			result += "{%s}" % _expression(text.substr(i + 1, close - i - 1), line_number)
			i = close + 1
			continue
		if character == "}":
			result += "}}"
			i += 1
			continue
		result += character
		i += 1
	return result


## Converts a Yarn expression to TaleScript.
func _expression(source: String, line_number: int) -> String:
	var result := ""
	var i := 0
	while i < source.length():
		var character := source[i]
		if character == "\"":
			var close := i + 1
			while close < source.length() and source[close] != "\"":
				close += 2 if source[close] == "\\" else 1
			result += source.substr(i, close - i + 1)
			i = close + 1
			continue
		if character == "$":
			var end := i + 1
			while end < source.length() and (source[end] == "_" or source[end].is_valid_identifier() or source[end].is_valid_int()):
				end += 1
			var variable := _variable_name(source.substr(i, end - i))
			if not _variables.has(variable):
				_note_variable(variable, "0", false)
			result += variable
			i = end
			continue
		var matched := false
		for symbol in ["&&", "||"]:
			if source.substr(i, 2) == symbol:
				result += " %s " % SYMBOL_OPERATORS[symbol]
				i += 2
				matched = true
				break
		if matched:
			continue
		if character == "!" and source.substr(i, 2) != "!=":
			result += "not "
			i += 1
			continue
		if character == "_" or character.is_valid_identifier():
			var end := i
			while end < source.length() and (source[end] == "_" or source[end].is_valid_identifier() or source[end].is_valid_int()):
				end += 1
			var word := source.substr(i, end - i)
			i = end
			if WORD_OPERATORS.has(word):
				result += " %s " % WORD_OPERATORS[word]
				continue
			var call := _function(word, source, i, line_number)
			result += call[0]
			i = call[1]
			continue
		result += character
		i += 1
	while result.contains("  "):
		result = result.replace("  ", " ")
	return result.replace("( ", "(").replace(" )", ")").strip_edges()


## Converts a name, and for some Yarn functions their arguments, starting
## at [param after] in [param source]. Returns [code][text, next index][/code].
func _function(word: String, source: String, after: int, line_number: int) -> Array:
	var open := after
	while open < source.length() and source[open] == " ":
		open += 1
	if open >= source.length() or source[open] != "(":
		return [word, after]
	var close := source.find(")", open)
	if close < 0:
		return [word, after]
	var argument := source.substr(open + 1, close - open - 1).strip_edges()
	match word:
		"visited":
			# Yarn names a node; TaleScript names "tale.beat".
			var title := argument.trim_prefix("\"").trim_suffix("\"")
			if _beats.has(title):
				var beat_id: String = _beats[title] if _tale_name.is_empty() else "%s.%s" % [_tale_name, _beats[title]]
				return ["visited(%s)" % TaleExpr.quote(beat_id), close + 1]
			_notes.append("Line %d: visited() names no node of this file." % line_number)
		"random":
			return ["randf()", close + 1]
		"random_range":
			return ["randi_range(%s)" % _expression(argument, line_number), close + 1]
		"dice":
			return ["randi_range(1, %s)" % _expression(argument, line_number), close + 1]
		"visited_count", "string", "number", "bool", "format_invariant":
			_notes.append("Line %d: %s() has no TaleScript equivalent; check this line." % [line_number, word])
	return [word, after]


static func _split_assignment(text: String) -> Array:
	for separator in [" to ", "="]:
		var at := text.find(separator)
		if at > 0:
			return [text.substr(0, at).strip_edges(), text.substr(at + separator.length()).strip_edges()]
	return []


func _note_variable(variable: String, value: String, declared: bool) -> void:
	if not _variables.has(variable) or (declared and not _variables[variable][1]):
		var start := value
		if not declared:
			start = _default_like(value)
		_variables[variable] = [start, declared]


## A starting value of the same type as [param value]: false, "", or 0.
static func _default_like(value: String) -> String:
	if value == "true" or value == "false" or value.begins_with("not "):
		return "false"
	for operator in [" and ", " or ", "==", "!=", ">", "<"]:
		if value.contains(operator):
			return "false"
	if value.begins_with("\""):
		return "\"\""
	if value.is_valid_float() and value.contains("."):
		return "0.0"
	return "0"


func _variable_name(text: String) -> String:
	return _identifier(text.strip_edges().trim_prefix("$"))


## The TaleScript name for a Yarn speaker.
func _speaker(name: String) -> String:
	if _speakers.has(name):
		return _speakers[name]
	var id := _identifier(name)
	if id not in _cast_ids:
		while _variables.has(id) or id in _beats.values():
			id += "_name"
		_speaker_consts[id] = name
	_speakers[name] = id
	return id


## Position of the colon after a speaker name, or -1 for narration.
static func _speaker_colon(text: String) -> int:
	var colon := text.find(":")
	if colon <= 0:
		return -1
	var name := text.substr(0, colon)
	for character in name:
		if not (character == " " or character == "_" or character.is_valid_identifier() or character.is_valid_int()):
			return -1
	return colon


func _id_prefix(tags: PackedStringArray, line_number: int) -> String:
	for tag in tags:
		if tag.begins_with("line:"):
			var id := tag.substr(5)
			if _used_ids.has(id):
				_notes.append("Line %d: line id '%s' is used twice; the second is dropped." % [line_number, id])
				return ""
			_used_ids[id] = true
			return "@id(%s) " % TaleExpr.quote(id)
	return ""


## Hashtags at the end of a line, without the #.
static func _tags_of(text: String) -> PackedStringArray:
	var tags := PackedStringArray()
	var words := text.split(" ", false)
	for i in range(words.size() - 1, -1, -1):
		if not words[i].begins_with("#"):
			break
		tags.append(words[i].substr(1))
	return tags


static func _strip_tags(text: String) -> String:
	var words := text.split(" ", false)
	while not words.is_empty() and words[words.size() - 1].begins_with("#"):
		words.remove_at(words.size() - 1)
	return " ".join(words)


## A valid TaleScript name for [param text]: snake_case, letters, digits,
## and underscores, not a keyword.
static func _identifier(text: String) -> String:
	var name := text.strip_edges().to_snake_case()
	var cleaned := ""
	for character in name:
		cleaned += character if (character == "_" or character.is_valid_identifier() or character.is_valid_int()) else "_"
	if cleaned.is_empty() or cleaned[0].is_valid_int():
		cleaned = "n_" + cleaned
	if cleaned in KEYWORDS:
		cleaned += "_"
	return cleaned

class_name TaleDocument
extends RefCounted
## A parsed tale: its syntax tree, its diagnostics, and its original lines.
##
## Created by [method TaleParser.parse]. [method to_source] rebuilds the text
## from the tree and returns exactly the original source, which lets editors
## change one statement without disturbing the rest of the file.

## Path of the tale file, or "" for text parsed from memory.
var path := ""
## Top-level statements in source order.
var statements: Array[TaleNode] = []
## Errors and warnings, in source order.
var diagnostics: Array[TaleDiagnostic] = []
## The source split on "\n". Line endings such as "\r" stay in each line.
var lines := PackedStringArray()


func has_errors() -> bool:
	for diagnostic in diagnostics:
		if diagnostic.is_error():
			return true
	return false


## Returns the top-level beat called [param beat_name], or null.
func find_beat(beat_name: String) -> TaleNode:
	for statement in statements:
		if statement.kind == TaleNode.Kind.BEAT and statement.name == beat_name:
			return statement
	return null


## Rebuilds the source text by walking the tree.
func to_source() -> String:
	var out := PackedStringArray()
	_collect_lines(statements, out)
	if lines.size() > _content_line_count():
		out.append(lines[lines.size() - 1])
	return "\n".join(out)


## Returns the indented tree dump followed by any diagnostics, used by tests.
func dump() -> String:
	var text := ""
	for statement in statements:
		text += statement.dump()
	if not diagnostics.is_empty():
		text += "--- diagnostics ---\n"
		for diagnostic in diagnostics:
			text += "%s\n" % diagnostic
	return text


## Number of lines holding content. A trailing "\n" adds an empty final
## element to [member lines] that is not a line of its own.
func _content_line_count() -> int:
	if lines.size() > 0 and lines[lines.size() - 1] == "":
		return lines.size() - 1
	return lines.size()


func _collect_lines(nodes: Array[TaleNode], out: PackedStringArray) -> void:
	for node in nodes:
		if not node.inline:
			for line_number in range(node.line_start, node.line_end + 1):
				out.append(lines[line_number - 1])
		_collect_lines(node.body, out)

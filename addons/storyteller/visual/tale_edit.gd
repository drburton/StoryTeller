class_name TaleEdit
extends RefCounted
## Text edits for the visual editor. Each one changes only the lines of the
## statements it touches and returns the new source, so comments,
## formatting, and the rest of the file stay as they were (decision 0010).
##
## Nodes come from [method TaleParser.parse] of the same source. After an
## edit, parse the result again before making the next one.


## First and last line (1-based) of [param node] and its body, leaving out
## blank lines at the end of the body.
static func span(node: TaleNode) -> Vector2i:
	return Vector2i(node.line_start, _end_line(node))


## Replaces lines [param first] to [param last] (1-based, inclusive) with
## [param new_lines]. With [code]last < first[/code] the lines are inserted
## before line [param first].
static func replace_lines(source: String, first: int, last: int, new_lines: PackedStringArray) -> String:
	var lines := source.split("\n")
	var crlf := lines.size() > 1 and lines[0].ends_with("\r")
	var added := PackedStringArray()
	for line in new_lines:
		added.append(line + "\r" if crlf else line)
	var before := lines.slice(0, first - 1)
	var after := lines.slice(maxi(last, first - 1))
	return "\n".join(before + added + after)


## Rewrites the header line of [param node] (not its body) as [param text],
## keeping its indentation.
static func set_statement(source: String, node: TaleNode, text: String) -> String:
	return replace_lines(source, node.line_start, node.line_end, _indented(text, node.indent))


## Replaces [param node] and its body with [param text], written without the
## node's indentation (nested lines keep their relative indentation).
static func replace_block(source: String, node: TaleNode, text: String) -> String:
	var block := span(node)
	return replace_lines(source, block.x, block.y, _indented(text, node.indent))


## The text of [param node] and its body with the node's indentation removed.
static func block_text(source: String, node: TaleNode) -> String:
	var lines := source.split("\n")
	var block := span(node)
	var out := PackedStringArray()
	for i in range(block.x - 1, block.y):
		var line := lines[i].trim_suffix("\r")
		out.append(line.substr(node.indent.length()) if line.begins_with(node.indent) else line.strip_edges(true, false))
	return "\n".join(out)


## Inserts [param text] as a new statement before [param anchor].
static func insert_before(source: String, anchor: TaleNode, text: String) -> String:
	return replace_lines(source, anchor.line_start, anchor.line_start - 1, _indented(text, anchor.indent))


## Inserts [param text] as a new statement after [param anchor] and its body.
static func insert_after(source: String, anchor: TaleNode, text: String) -> String:
	var end := span(anchor).y
	return replace_lines(source, end + 1, end, _indented(text, anchor.indent))


## Adds [param text] as the last statement of the block [param parent]
## (a beat, option, if, ...). A lone [code]pass[/code] is replaced.
static func append_to(source: String, doc: TaleDocument, parent: TaleNode, text: String) -> String:
	var children := content_children(parent)
	if children.is_empty():
		var indent := child_indent(doc, parent)
		var pass_node := _only_pass(parent)
		if pass_node != null and not pass_node.inline:
			return replace_lines(source, pass_node.line_start, pass_node.line_end, _indented(text, pass_node.indent))
		var end := span(parent).y
		return replace_lines(source, end + 1, end, _indented(text, indent))
	return insert_after(source, children.back(), text)


## Removes [param node] and its body. A block left without statements gets
## [code]pass[/code] so the tale stays valid.
static func delete(source: String, doc: TaleDocument, node: TaleNode) -> String:
	var block := span(node)
	var parent := find_parent(doc, node)
	if parent != null and content_children(parent).size() == 1 and parent.kind != TaleNode.Kind.CHOOSE:
		return replace_lines(source, block.x, block.y, PackedStringArray([node.indent + "pass"]))
	return replace_lines(source, block.x, block.y, PackedStringArray())


## Moves [param node] to position [param index] among the statements of the
## block [param parent] (counted without [param node] itself). Returns the
## new source.
static func move(source: String, doc: TaleDocument, node: TaleNode, parent: TaleNode, index: int) -> String:
	var text := block_text(source, node)
	var siblings := content_children(parent)
	siblings.erase(node)
	var anchor: TaleNode = siblings[index] if index < siblings.size() else null
	var anchor_line := anchor.line_start if anchor != null else -1
	var parent_line := parent.line_start
	var removed := span(node)
	var after_delete := delete(source, doc, node)
	# Lines after the removed block move up by this much.
	var shift := source.split("\n").size() - after_delete.split("\n").size()
	var new_doc := TaleParser.parse(after_delete)
	if anchor != null:
		var line := anchor_line - shift if anchor_line > removed.y else anchor_line
		var new_anchor := find_at_line(new_doc, line)
		return insert_before(after_delete, new_anchor, text)
	var new_parent := find_at_line(new_doc, parent_line - shift if parent_line > removed.y else parent_line)
	return append_to(after_delete, new_doc, new_parent, text)


## Statements of a block that the visual editor shows: everything except
## blank lines and lone [code]pass[/code] statements.
static func content_children(parent: TaleNode) -> Array[TaleNode]:
	var result: Array[TaleNode] = []
	for child in parent.body:
		if child.kind != TaleNode.Kind.BLANK and child.kind != TaleNode.Kind.PASS:
			result.append(child)
	return result


## Indentation for statements inside [param parent].
static func child_indent(doc: TaleDocument, parent: TaleNode) -> String:
	for child in parent.body:
		if child.kind != TaleNode.Kind.BLANK and not child.inline:
			return child.indent
	return parent.indent + indent_unit(doc)


## The file's indentation step: a tab, or the smallest run of spaces used.
static func indent_unit(doc: TaleDocument) -> String:
	var smallest := 0
	for line in doc.lines:
		if line.begins_with("\t"):
			return "\t"
		if line.begins_with(" ") and not line.strip_edges().is_empty():
			var count := line.length() - line.lstrip(" ").length()
			if smallest == 0 or count < smallest:
				smallest = count
	return " ".repeat(smallest) if smallest > 0 else "\t"


## The block that holds [param node], or null for top-level statements.
static func find_parent(doc: TaleDocument, node: TaleNode) -> TaleNode:
	var pending: Array = doc.statements.duplicate()
	while not pending.is_empty():
		var current: TaleNode = pending.pop_back()
		if node in current.body:
			return current
		pending.append_array(current.body)
	return null


## The statement that starts on [param line], or null.
static func find_at_line(doc: TaleDocument, line: int) -> TaleNode:
	var pending: Array = doc.statements.duplicate()
	while not pending.is_empty():
		var current: TaleNode = pending.pop_back()
		if current.line_start == line and current.kind != TaleNode.Kind.BLANK and not current.inline:
			return current
		pending.append_array(current.body)
	return null


## Adds a new beat at the end of the tale. Returns the new source.
static func add_beat(source: String, doc: TaleDocument, beat_name: String, first_line := "pass") -> String:
	var unit := indent_unit(doc)
	var text := source
	if not text.is_empty() and not text.ends_with("\n"):
		text += "\n"
	if not text.is_empty() and not text.ends_with("\n\n"):
		text += "\n"
	return text + "beat %s:\n%s%s\n" % [beat_name, unit, first_line]


static func _end_line(node: TaleNode) -> int:
	var end := node.line_end
	for i in range(node.body.size() - 1, -1, -1):
		var child := node.body[i]
		if child.kind != TaleNode.Kind.BLANK:
			return maxi(end, _end_line(child))
	return end


static func _only_pass(parent: TaleNode) -> TaleNode:
	for child in parent.body:
		if child.kind == TaleNode.Kind.PASS:
			return child
	return null


static func _indented(text: String, indent: String) -> PackedStringArray:
	var out := PackedStringArray()
	for line in text.split("\n"):
		out.append(indent + line if not line.strip_edges().is_empty() else "")
	return out

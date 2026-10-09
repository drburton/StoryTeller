class_name TaleLineIds
extends RefCounted
## Pins line ids: writes [code]@id("...")[/code] in front of every line of
## dialogue, narration, and every choice option that has none, using the id
## the line has now. Ids made from the text change when the text changes,
## which gives a line a new translation key and makes it unread; pinned
## ids stay. Only the changed lines are touched (decision 0012).
## [codeblock]
## var result := TaleLineIds.pin(source, "chapter_1")
## if result["error"].is_empty():
##     source = result["text"]   # result["count"] lines were pinned
## [/codeblock]


## Returns [code]{"text": String, "count": int, "error": String}[/code].
## A tale with syntax errors is returned unchanged with an error.
static func pin(source: String, tale_name: String) -> Dictionary:
	var doc := TaleParser.parse(source)
	if doc.has_errors():
		return {"text": source, "count": 0, "error": "Fix the syntax errors in %s first." % tale_name}
	var tale := TaleCompiler.compile(doc, tale_name)
	if tale == null:
		return {"text": source, "count": 0, "error": "%s can't be compiled." % tale_name}
	# Source line to the id the compiler gave the line or option there.
	var ids := {}
	for instruction in tale.instructions:
		if instruction["op"] == "say":
			ids[instruction["line"]] = instruction["id"]
		elif instruction["op"] == "choose":
			for option in instruction["options"]:
				ids[option["line"]] = option["id"]
	var targets := {}
	_collect(doc.statements, ids, targets)
	var lines := source.split("\n")
	for line_number in targets:
		var index: int = line_number - 1
		var text: String = lines[index]
		var indent := text.length() - text.strip_edges(true, false).length()
		lines[index] = text.substr(0, indent) + "@id(%s) " % TaleExpr.quote(targets[line_number]) + text.substr(indent)
	return {"text": "\n".join(lines), "count": targets.size(), "error": ""}


## Adds to [param targets] each line in [param nodes] (and nested blocks)
## that needs an id: source line to id.
static func _collect(nodes: Array[TaleNode], ids: Dictionary, targets: Dictionary) -> void:
	var pending_id := false
	for node in nodes:
		if node.kind == TaleNode.Kind.ANNOTATION:
			for annotation in node.annotations:
				pending_id = pending_id or annotation.name == "id"
			continue
		if node.is_trivia():
			continue
		var kind := node.kind
		if kind == TaleNode.Kind.DIALOGUE or kind == TaleNode.Kind.NARRATION or kind == TaleNode.Kind.OPTION:
			var has_id := pending_id
			for annotation in node.annotations:
				has_id = has_id or annotation.name == "id"
			if not has_id and ids.has(node.line_start):
				targets[node.line_start] = ids[node.line_start]
		pending_id = false
		_collect(node.body, ids, targets)

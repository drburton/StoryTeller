class_name StoryGraph
extends RefCounted
## The shape of a story for the Story Map: every beat of a set of tales,
## the jumps, beat calls, and choice branches between them, and the
## problems that show in that shape.
## [codeblock]
## var graph := StoryGraph.build({"prologue": doc, "chapter_1": other_doc}, "prologue")
## graph.beats["prologue.start"]["exits"]   # where it goes
## graph.unreachable                        # beats nothing leads to
## [/codeblock]

## "tale.beat" to [code]{"tale", "beat", "line", "statements", "ends", "exits": Array}[/code].
## Exits are [code]{"to", "kind" ("jump", "call", "choice"), "label", "line"}[/code].
var beats: Dictionary = {}
## Exits whose target beat does not exist: [code]{"from", "to", "line"}[/code].
var missing: Array[Dictionary] = []
## Beats that no path from an entry point reaches.
var unreachable := PackedStringArray()
## Where play can begin: each tale's "start" beat and the start tale's beat.
var entries := PackedStringArray()


## Builds the graph of [param docs] (tale name to [TaleDocument]).
## [param start_tale] and [param start_beat] add an entry point, as
## [member StoryConfig.start_tale] does for New Game.
static func build(docs: Dictionary, start_tale := "", start_beat := "start") -> StoryGraph:
	var graph := StoryGraph.new()
	var names := docs.keys()
	names.sort()
	for tale_name in names:
		var doc: TaleDocument = docs[tale_name]
		for statement in doc.statements:
			if statement.kind != TaleNode.Kind.BEAT:
				continue
			var id := "%s.%s" % [tale_name, statement.name]
			var info := {
				"tale": tale_name, "beat": statement.name, "line": statement.line_start,
				"statements": _count(statement), "ends": _falls_through(statement), "exits": [],
			}
			_collect_exits(statement, tale_name, docs, info["exits"], "")
			graph.beats[id] = info
	for id in graph.beats:
		for exit in graph.beats[id]["exits"]:
			if not graph.beats.has(exit["to"]):
				graph.missing.append({"from": id, "to": exit["to"], "line": exit["line"]})
	var start_id := "%s.%s" % [start_tale, start_beat]
	if graph.beats.has(start_id):
		graph.entries.append(start_id)
	for id in graph.beats:
		if graph.beats[id]["beat"] == "start" and id not in graph.entries:
			graph.entries.append(id)
	var reached := {}
	var pending := Array(graph.entries)
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if reached.has(id) or not graph.beats.has(id):
			continue
		reached[id] = true
		for exit in graph.beats[id]["exits"]:
			pending.append(exit["to"])
	for id in graph.beats:
		if not reached.has(id):
			graph.unreachable.append(id)
	return graph


## Rows of text a beat's box shows on the map: its tale, its size, one row
## per choice, its problems, and whether the story can end there.
func rows_for(id: String) -> int:
	var rows := 2
	for exit in beats[id]["exits"]:
		if exit["kind"] == "choice":
			rows += 1
	for problem in missing:
		if problem["from"] == id:
			rows += 1
	if id in unreachable:
		rows += 1
	if beats[id]["ends"]:
		rows += 1
	return rows


## Tale names in the order play first reaches them from the entry points,
## then the rest by name.
func tale_order() -> PackedStringArray:
	var order := PackedStringArray()
	var seen := {}
	for entry in entries:
		var queue := [entry]
		while not queue.is_empty():
			var id: String = queue.pop_front()
			if seen.has(id) or not beats.has(id):
				continue
			seen[id] = true
			if beats[id]["tale"] not in order:
				order.append(beats[id]["tale"])
			for exit in beats[id]["exits"]:
				queue.append(exit["to"])
	var rest := PackedStringArray()
	for id in beats:
		if beats[id]["tale"] not in order and beats[id]["tale"] not in rest:
			rest.append(beats[id]["tale"])
	rest.sort()
	order.append_array(rest)
	return order


## Positions for the beats: one horizontal band per tale (in [param order],
## then in [method tale_order]), and within it one column per step from the
## tale's entry beats. Beats in a column are stacked by their height
## ([param row_height] per row from [method rows_for], plus
## [param gap]). Returns "tale.beat" to Vector2.
func layout(order: PackedStringArray = [], column_width := 280.0, row_height := 30.0, gap := 40.0) -> Dictionary:
	var tales := PackedStringArray(order)
	for tale in tale_order():
		if tale not in tales:
			tales.append(tale)
	var positions := {}
	var band_top := 0.0
	for tale in tales:
		var ids: Array[String] = []
		for id in beats:
			if beats[id]["tale"] == tale:
				ids.append(id)
		if ids.is_empty():
			continue
		ids.sort_custom(func(a: String, b: String) -> bool: return beats[a]["line"] < beats[b]["line"])
		var depth := {}
		var queue: Array = []
		for id in ids:
			if id in entries or _entered_from_outside(id, tale):
				depth[id] = 0
				queue.append(id)
		if queue.is_empty():
			depth[ids[0]] = 0
			queue.append(ids[0])
		while not queue.is_empty():
			var id: String = queue.pop_front()
			for exit in beats[id]["exits"]:
				var to: String = exit["to"]
				if beats.has(to) and beats[to]["tale"] == tale and not depth.has(to):
					depth[to] = depth[id] + 1
					queue.append(to)
		var deepest := 0
		for id in depth:
			deepest = maxi(deepest, depth[id])
		for id in ids:
			if not depth.has(id):
				deepest += 1
				depth[id] = deepest
		var column_tops := {}
		var band_bottom := band_top
		for id in ids:
			var column: int = depth[id]
			var top: float = column_tops.get(column, band_top)
			positions[id] = Vector2(column * column_width, top)
			var bottom := top + (rows_for(id) + 1.5) * row_height
			column_tops[column] = bottom + gap
			band_bottom = maxf(band_bottom, bottom)
		band_top = band_bottom + gap * 2.0
	return positions


func _entered_from_outside(id: String, tale: String) -> bool:
	for other in beats:
		if beats[other]["tale"] == tale:
			continue
		for exit in beats[other]["exits"]:
			if exit["to"] == id:
				return true
	return false


static func _collect_exits(node: TaleNode, tale_name: String, docs: Dictionary, exits: Array, label: String) -> void:
	for child in node.body:
		match child.kind:
			TaleNode.Kind.JUMP:
				exits.append({"to": _resolve(child.jump_target, tale_name), "kind": "choice" if not label.is_empty() else "jump", "label": label, "line": child.line_start})
			TaleNode.Kind.EXPRESSION:
				var target := _beat_call(child.expr, tale_name, docs)
				if not target.is_empty():
					exits.append({"to": target, "kind": "call", "label": label, "line": child.line_start})
		var child_label := label
		if child.kind == TaleNode.Kind.OPTION:
			child_label = TaleCard.text_of(child)
		elif child.kind == TaleNode.Kind.TIMEOUT:
			child_label = "timeout"
		_collect_exits(child, tale_name, docs, exits, child_label)


static func _resolve(target: String, tale_name: String) -> String:
	return target if "." in target else "%s.%s" % [tale_name, target]


## "tale.beat" for a statement like [code]other()[/code] or
## [code]chapter.scene()[/code], or "".
static func _beat_call(expr: TaleExpr, tale_name: String, docs: Dictionary) -> String:
	if expr.kind == TaleExpr.Kind.AWAIT:
		expr = expr.operands[0]
	if expr.kind != TaleExpr.Kind.CALL or not expr.args.is_empty():
		return ""
	var callee := expr.operands[0]
	if callee.kind == TaleExpr.Kind.IDENTIFIER and docs[tale_name].find_beat(callee.name) != null:
		return "%s.%s" % [tale_name, callee.name]
	if callee.kind == TaleExpr.Kind.ATTRIBUTE and callee.operands[0].kind == TaleExpr.Kind.IDENTIFIER and docs.has(callee.operands[0].name):
		return "%s.%s" % [callee.operands[0].name, callee.name]
	return ""


static func _count(node: TaleNode) -> int:
	var total := 0
	for child in node.body:
		if not child.is_trivia() and child.kind != TaleNode.Kind.PASS:
			total += 1 + _count(child)
	return total


## True if play can run off the end of [param beat] (ending the story or
## returning to a caller) rather than always jumping somewhere.
static func _falls_through(beat: TaleNode) -> bool:
	var children := TaleEdit.content_children(beat)
	while not children.is_empty() and children.back().kind == TaleNode.Kind.COMMENT:
		children.pop_back()
	if children.is_empty():
		return true
	var last: TaleNode = children.back()
	if last.kind == TaleNode.Kind.JUMP:
		return false
	if last.kind == TaleNode.Kind.CHOOSE:
		for option in last.body:
			if (option.kind == TaleNode.Kind.OPTION or option.kind == TaleNode.Kind.TIMEOUT) and _falls_through(option):
				return true
		return false
	return true

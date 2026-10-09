class_name TaleCompiler
extends RefCounted
## Turns a parsed and checked [TaleDocument] into a [Tale] resource.
##
## Control flow (if, loops, match, choose) becomes jumps between instruction
## indices, so the director only needs a position and a call stack to run,
## save, and restore a tale.

const K := TaleNode.Kind
const E := TaleExpr.Kind

var _tale: Tale
var _call_kinds: Dictionary
var _beat := ""
## True while compiling a beat marked @skip_safe.
var _skip_safe := false
var _loop_counter := 0
## Stack of open loops: {"continue": index, "breaks": Array[int]}.
var _loops: Array[Dictionary] = []
var _used_ids: Dictionary = {}


## Compiles [param doc]. [param call_kinds] comes from [member TaleChecker.call_kinds]
## and tells which calls are beat calls. Returns null if the document has parse errors.
static func compile(doc: TaleDocument, tale_name: String, call_kinds: Dictionary = {}) -> Tale:
	if doc.has_errors():
		return null
	return TaleCompiler.new()._compile(doc, tale_name, call_kinds)


## Compiles a line of text with [code]{expr}[/code] interpolation, such as a
## translated line, into text parts. Returns
## [code]{"parts": Array, "errors": PackedStringArray}[/code].
static func compile_text(text: String) -> Dictionary:
	var split := TaleText.split_interpolation(text)
	var compiler := TaleCompiler.new()
	var parts: Array = []
	for part in split["parts"]:
		parts.append(compiler._text_part(part))
	return {"parts": parts, "errors": split.get("errors", PackedStringArray())}


## Parses, checks, and compiles [param source] in one step. Returns
## [code]{"tale": Tale or null, "diagnostics": Array[TaleDiagnostic]}[/code].
## The tale is null when there are errors.
static func build(source: String, tale_name: String, context: TaleCheckContext = null, path := "") -> Dictionary:
	var doc := TaleParser.parse(source, path)
	var diagnostics: Array[TaleDiagnostic] = []
	diagnostics.append_array(doc.diagnostics)
	if doc.has_errors():
		return {"tale": null, "diagnostics": diagnostics}
	if context == null:
		context = TaleCheckContext.new()
	if context.tale_name.is_empty():
		context.tale_name = tale_name
	var checker := TaleChecker.new()
	var problems := checker.run(doc, context)
	diagnostics.append_array(problems)
	for problem in problems:
		if problem.is_error():
			return {"tale": null, "diagnostics": diagnostics}
	var tale := compile(doc, tale_name, checker.call_kinds)
	tale.source_path = path
	return {"tale": tale, "diagnostics": diagnostics}


func _compile(doc: TaleDocument, tale_name: String, call_kinds: Dictionary) -> Tale:
	_tale = Tale.new()
	_tale.tale_name = tale_name
	_tale.source_path = doc.path
	_call_kinds = call_kinds
	var pending: Array[TaleExpr] = []
	for node in doc.statements:
		match node.kind:
			K.ANNOTATION:
				for annotation in node.annotations:
					if annotation.name == "title" and annotation.args.size() == 1:
						_tale.title = annotation.args[0].value
					else:
						pending.append(annotation)
			K.VAR, K.CONST:
				_tale.variables.append({
					"name": node.name,
					"global": _has_annotation(pending, node, "global"),
					"const": node.kind == K.CONST,
					"value": _expr(node.expr) if node.expr else null,
					"line": node.line_start,
				})
				pending.clear()
			K.BEAT:
				_beat = node.name
				_skip_safe = _has_annotation(pending, node, "skip_safe")
				var beat_annotations: Array[TaleExpr] = pending.duplicate()
				beat_annotations.append_array(node.annotations)
				var heading := _annotation_text(beat_annotations, "heading")
				if not heading.is_empty():
					_tale.headings[node.name] = heading
				_tale.beats[node.name] = _tale.instructions.size()
				_block(node.body)
				_emit({"op": "end"}, node.line_end)
				pending.clear()
	return _tale


# --- Statements ---------------------------------------------------------------

func _block(nodes: Array[TaleNode]) -> void:
	var pending: Array[TaleExpr] = []
	var i := 0
	while i < nodes.size():
		var node := nodes[i]
		i += 1
		if node.is_trivia() or node.kind == K.PASS:
			continue
		if node.kind == K.ANNOTATION:
			pending.append_array(node.annotations)
			continue
		if node.kind == K.IF:
			var chain: Array[TaleNode] = [node]
			while i < nodes.size():
				var next := nodes[i]
				if next.is_trivia():
					i += 1
				elif next.kind == K.ELIF or next.kind == K.ELSE:
					chain.append(next)
					i += 1
					if next.kind == K.ELSE:
						break
				else:
					break
			_if_chain(chain, pending)
		else:
			_statement(node, pending)
		pending.clear()


func _statement(node: TaleNode, pending: Array[TaleExpr]) -> void:
	var annotations: Array[TaleExpr] = []
	annotations.append_array(pending)
	annotations.append_array(node.annotations)
	var index := _tale.instructions.size()
	match node.kind:
		K.DIALOGUE, K.NARRATION:
			_emit({
				"op": "say",
				"speaker": node.name if node.kind == K.DIALOGUE else "",
				"mood": node.mood,
				"text": _text(node.expr.value),
				"id": _line_id(annotations, node.expr.value),
				"voice": _annotation_text(annotations, "voice"),
			}, node.line_start)
		K.EXPRESSION:
			var kind: String = _call_kinds.get(node.expr, "")
			if kind == "beat":
				_emit({"op": "call_beat", "tale": "", "beat": node.expr.operands[0].name}, node.line_start)
			elif kind == "tale_beat":
				var callee := node.expr.operands[0]
				_emit({"op": "call_beat", "tale": callee.operands[0].name, "beat": callee.name}, node.line_start)
			else:
				_emit({"op": "eval", "expr": _expr(node.expr)}, node.line_start)
		K.ASSIGN:
			_emit({"op": "set", "place": _expr(node.target), "assign": node.op, "value": _expr(node.expr)}, node.line_start)
		K.VAR, K.CONST:
			_emit({"op": "local", "name": node.name, "value": _expr(node.expr) if node.expr else null}, node.line_start)
		K.JUMP:
			var parts := node.jump_target.split(".")
			var tale := parts[0] if parts.size() == 2 else ""
			_emit({"op": "jump", "tale": tale, "beat": parts[parts.size() - 1]}, node.line_start)
		K.RETURN:
			_emit({"op": "return"}, node.line_start)
		K.WHILE:
			_while(node)
		K.FOR:
			_for(node)
		K.MATCH:
			_match(node)
		K.CHOOSE:
			_choose(node)
		K.BREAK:
			_loops.back()["breaks"].append(_emit({"op": "goto", "target": -1}, node.line_start))
		K.CONTINUE:
			_emit({"op": "goto", "target": _loops.back()["continue"]}, node.line_start)
	if _has_annotation(annotations, null, "no_rewind") and index < _tale.instructions.size():
		_tale.instructions[index]["no_rewind"] = true


func _if_chain(chain: Array[TaleNode], pending: Array[TaleExpr]) -> void:
	var exits: Array[int] = []
	var first := _tale.instructions.size()
	for branch in chain:
		if branch.kind == K.ELSE:
			_block(branch.body)
			break
		var test := _emit({"op": "branch_false", "cond": _expr(branch.expr), "target": -1}, branch.line_start)
		_block(branch.body)
		if branch != chain.back():
			exits.append(_emit({"op": "goto", "target": -1}, branch.line_start))
		_patch(test)
	for exit in exits:
		_patch(exit)
	if _has_annotation(pending, null, "no_rewind") and first < _tale.instructions.size():
		_tale.instructions[first]["no_rewind"] = true


func _while(node: TaleNode) -> void:
	var start := _tale.instructions.size()
	var test := _emit({"op": "branch_false", "cond": _expr(node.expr), "target": -1}, node.line_start)
	_loops.append({"continue": start, "breaks": []})
	_block(node.body)
	_emit({"op": "goto", "target": start}, node.line_start)
	_close_loop(test)


func _for(node: TaleNode) -> void:
	_loop_counter += 1
	var slot := "$for%d" % _loop_counter
	_emit({"op": "iter_begin", "slot": slot, "iterable": _expr(node.expr)}, node.line_start)
	var next := _emit({"op": "iter_next", "slot": slot, "var": node.name, "target": -1}, node.line_start)
	_loops.append({"continue": next, "breaks": []})
	_block(node.body)
	_emit({"op": "goto", "target": next}, node.line_start)
	_close_loop(next)


## Points the loop's exit instruction and its breaks past the loop.
func _close_loop(exit: int) -> void:
	_patch(exit)
	for break_index in _loops.pop_back()["breaks"]:
		_patch(break_index)


func _match(node: TaleNode) -> void:
	var branches: Array[Dictionary] = []
	var instruction := _emit({"op": "match", "subject": _expr(node.expr), "branches": branches, "end": -1}, node.line_start)
	var exits: Array[int] = []
	for branch in node.body:
		if branch.kind != K.MATCH_BRANCH:
			continue
		var patterns: Array = []
		for pattern in branch.patterns:
			var wildcard := pattern.kind == E.IDENTIFIER and pattern.name == "_"
			patterns.append(null if wildcard else _expr(pattern))
		branches.append({
			"patterns": patterns,
			"guard": _expr(branch.condition) if branch.condition else null,
			"target": _tale.instructions.size(),
		})
		_block(branch.body)
		exits.append(_emit({"op": "goto", "target": -1}, branch.line_start))
	_tale.instructions[instruction]["end"] = _tale.instructions.size()
	for exit in exits:
		_patch(exit)


func _choose(node: TaleNode) -> void:
	var args := {}
	if node.expr:
		for key in node.expr.named_args:
			args[key] = _expr(node.expr.named_args[key])
	var options: Array[Dictionary] = []
	var instruction := _emit({"op": "choose", "args": args, "options": options, "timeout_target": -1, "end": -1}, node.line_start)
	var exits: Array[int] = []
	var pending: Array[TaleExpr] = []
	for child in node.body:
		if child.kind == K.ANNOTATION:
			pending.append_array(child.annotations)
			continue
		if child.kind != K.OPTION and child.kind != K.TIMEOUT:
			continue
		var target := _tale.instructions.size()
		if child.kind == K.TIMEOUT:
			_tale.instructions[instruction]["timeout_target"] = target
		else:
			var annotations: Array[TaleExpr] = []
			annotations.append_array(pending)
			annotations.append_array(child.annotations)
			options.append({
				"text": _text(child.expr.value),
				"cond": _expr(child.condition) if child.condition else null,
				"once": _has_annotation(annotations, null, "once"),
				"show_disabled": _has_annotation(annotations, null, "show_disabled"),
				"picture": _annotation_text(annotations, "picture"),
				"id": _line_id(annotations, child.expr.value),
				"target": target,
				"line": child.line_start,
			})
		pending.clear()
		_block(child.body)
		exits.append(_emit({"op": "goto", "target": -1}, child.line_start))
	_tale.instructions[instruction]["end"] = _tale.instructions.size()
	for exit in exits:
		_patch(exit)


# --- Expressions and text ---------------------------------------------------

func _expr(expr: TaleExpr) -> Array:
	match expr.kind:
		E.LITERAL:
			return ["lit", expr.value]
		E.IDENTIFIER:
			return ["name", expr.name]
		E.UNARY:
			return ["un", expr.op, _expr(expr.operands[0])]
		E.BINARY:
			return ["bin", expr.op, _expr(expr.operands[0]), _expr(expr.operands[1])]
		E.TERNARY:
			return ["if", _expr(expr.operands[1]), _expr(expr.operands[0]), _expr(expr.operands[2])]
		E.AWAIT:
			return ["await", _expr(expr.operands[0])]
		E.CALL:
			var args: Array = []
			for argument in expr.args:
				args.append(_expr(argument))
			var named := {}
			for key in expr.named_args:
				named[key] = _expr(expr.named_args[key])
			return ["call", _expr(expr.operands[0]), args, named]
		E.ATTRIBUTE:
			return ["attr", _expr(expr.operands[0]), expr.name]
		E.INDEX:
			return ["idx", _expr(expr.operands[0]), _expr(expr.operands[1])]
		E.ARRAY, E.DICTIONARY:
			var items: Array = []
			for operand in expr.operands:
				items.append(_expr(operand))
			return ["arr" if expr.kind == E.ARRAY else "dict", items]
	return ["lit", null]


func _text(text: String) -> Array:
	var parts: Array = []
	for part in TaleText.split_interpolation(text)["parts"]:
		parts.append(_text_part(part))
	return parts


## A text part as the director uses it: a String, a compiled expression
## (Array), or [code]{"tag": "act" or "sound", "expr": compiled}[/code].
func _text_part(part: Variant) -> Variant:
	if part is TaleExpr:
		return _expr(part)
	if part is Dictionary:
		return {"tag": part["tag"], "expr": _expr(part["expr"])}
	return part


## Pinned id from @id, or "<beat>_<hash>" made unique within the tale.
func _line_id(annotations: Array[TaleExpr], text: String) -> String:
	var pinned := _annotation_text(annotations, "id")
	if not pinned.is_empty():
		_tale.texts[pinned] = text
		return pinned
	var base := "%s_%s" % [_beat, text.md5_text().substr(0, 6)]
	var id := base
	var n := 2
	while _used_ids.has(id):
		id = "%s_%d" % [base, n]
		n += 1
	_used_ids[id] = true
	_tale.texts[id] = text
	return id


# --- Helpers ----------------------------------------------------------------

func _emit(instruction: Dictionary, line: int) -> int:
	instruction["line"] = line
	if _skip_safe and instruction["op"] == "say":
		instruction["skip_safe"] = true
	_tale.instructions.append(instruction)
	return _tale.instructions.size() - 1


## Points the jump at [param index] to the next instruction to be emitted.
func _patch(index: int) -> void:
	_tale.instructions[index]["target"] = _tale.instructions.size()


static func _has_annotation(annotations: Array[TaleExpr], node: TaleNode, annotation_name: String) -> bool:
	for annotation in annotations:
		if annotation.name == annotation_name:
			return true
	if node != null:
		for annotation in node.annotations:
			if annotation.name == annotation_name:
				return true
	return false


static func _annotation_text(annotations: Array[TaleExpr], annotation_name: String) -> String:
	for annotation in annotations:
		if annotation.name == annotation_name and annotation.args.size() == 1 and annotation.args[0].value is String:
			return annotation.args[0].value
	return ""

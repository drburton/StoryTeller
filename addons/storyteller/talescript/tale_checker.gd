class_name TaleChecker
extends RefCounted
## Finds mistakes in a parsed tale that the parser cannot see: unknown names,
## statements in the wrong place, wrong arguments, misused annotations, and
## code that can never run.
##
## [codeblock]
## var doc := TaleParser.parse(source)
## var problems := TaleChecker.check(doc, context)
## [/codeblock]

const K := TaleNode.Kind
const E := TaleExpr.Kind

## How each call expression was resolved, for the compiler. Maps a TaleExpr
## to "beat", "tale_beat", "action", "function", "constructor", "exposed",
## "method", or "choose".
var call_kinds: Dictionary = {}

var _doc: TaleDocument
var _context: TaleCheckContext
var _diagnostics: Array[TaleDiagnostic] = []
## Top-level VAR and CONST nodes by name.
var _story_vars: Dictionary = {}
## BEAT nodes by name.
var _beats: Dictionary = {}
## Block scopes, innermost last. Each maps a name to "var" or "const".
var _scopes: Array[Dictionary] = []
## Pinned line ids seen so far, mapped to their line number.
var _line_ids: Dictionary = {}


## Checks [param doc] and returns the problems found, sorted by position.
## Parse errors are not repeated; they stay in [member TaleDocument.diagnostics].
static func check(doc: TaleDocument, context: TaleCheckContext = null) -> Array[TaleDiagnostic]:
	return TaleChecker.new().run(doc, context)


func run(doc: TaleDocument, context: TaleCheckContext = null) -> Array[TaleDiagnostic]:
	_doc = doc
	_context = context if context != null else TaleCheckContext.new()
	_diagnostics = []
	_story_vars.clear()
	_beats.clear()
	_scopes.clear()
	_line_ids.clear()
	call_kinds.clear()
	_collect_declarations()
	_check_top_level()
	_diagnostics.sort_custom(func(a: TaleDiagnostic, b: TaleDiagnostic) -> bool:
		return a.line < b.line or (a.line == b.line and a.column < b.column))
	return _diagnostics


# --- Top level --------------------------------------------------------------

func _collect_declarations() -> void:
	for node in _doc.statements:
		if node.kind not in [K.VAR, K.CONST, K.BEAT]:
			continue
		var previous: TaleNode = _story_vars.get(node.name, _beats.get(node.name))
		if previous != null:
			_error_node(node, "'%s' is already declared on line %d." % [node.name, previous.line_start])
		elif node.kind == K.BEAT:
			_beats[node.name] = node
		else:
			_story_vars[node.name] = node


func _check_top_level() -> void:
	var pending: Array[TaleExpr] = []
	var has_title := false
	for node in _doc.statements:
		if node.is_trivia() or node.kind == K.ERROR:
			continue
		if node.kind == K.ANNOTATION:
			for annotation in node.annotations:
				if annotation.name == "title":
					if has_title:
						_error_expr(annotation, "A tale can only have one @title.")
					_expect_one_string(annotation)
					has_title = true
				else:
					pending.append(annotation)
			continue
		_check_annotations(_merge(pending, node.annotations), node, true)
		pending.clear()
		match node.kind:
			K.VAR, K.CONST:
				if node.expr:
					_check_expr(node.expr)
			K.BEAT:
				_check_block(node.body, false)
	_report_unused_annotations(pending)


# --- Blocks and statements --------------------------------------------------

func _check_block(nodes: Array[TaleNode], in_loop: bool) -> void:
	_scopes.append({})
	var pending: Array[TaleExpr] = []
	var previous := -1
	var left_block := false
	var warned_unreachable := false
	for node in nodes:
		if node.is_trivia():
			continue
		if node.kind == K.ANNOTATION:
			pending.append_array(node.annotations)
			previous = node.kind
			continue
		if node.kind == K.ERROR:
			pending.clear()
			previous = node.kind
			continue
		_check_annotations(_merge(pending, node.annotations), node, false)
		pending.clear()
		if left_block and not warned_unreachable:
			_warn_node(node, "This line can never run, because the line before it always leaves the block.")
			warned_unreachable = true
		if node.kind in [K.ELIF, K.ELSE] and previous not in [K.IF, K.ELIF, K.ERROR]:
			_error_node(node, "'%s' must follow an 'if' or 'elif' block." % ("elif" if node.kind == K.ELIF else "else"))
		_check_statement(node, in_loop)
		previous = node.kind
		if node.kind in [K.JUMP, K.RETURN, K.BREAK, K.CONTINUE]:
			left_block = true
	_report_unused_annotations(pending)
	_scopes.pop_back()


func _check_statement(node: TaleNode, in_loop: bool) -> void:
	match node.kind:
		K.VAR, K.CONST:
			if node.expr:
				_check_expr(node.expr)
			_declare(node)
		K.DIALOGUE:
			_check_speaker(node)
			_check_text(node.expr)
		K.NARRATION:
			_check_text(node.expr)
		K.JUMP:
			_check_jump(node)
		K.EXPRESSION:
			_check_expr(node.expr)
			if node.expr.kind != E.CALL and node.expr.kind != E.AWAIT:
				_warn_node(node, "This expression has no effect.")
		K.ASSIGN:
			_check_assign_target(node)
			_check_expr(node.expr)
		K.IF, K.ELIF:
			_check_expr(node.expr)
			_check_block(node.body, in_loop)
		K.WHILE:
			_check_expr(node.expr)
			_check_block(node.body, true)
		K.ELSE, K.TIMEOUT:
			_check_block(node.body, in_loop)
		K.FOR:
			_check_expr(node.expr)
			_scopes.append({node.name: "var"})
			_check_block(node.body, true)
			_scopes.pop_back()
		K.MATCH:
			_check_expr(node.expr)
			_check_match(node, in_loop)
		K.MATCH_BRANCH:
			for pattern in node.patterns:
				_check_pattern(pattern)
			if node.condition:
				_check_expr(node.condition)
			_check_block(node.body, in_loop)
		K.CHOOSE:
			_check_choose(node, in_loop)
		K.OPTION:
			_check_text(node.expr)
			if node.condition:
				_check_expr(node.condition)
			_check_block(node.body, in_loop)
		K.RETURN:
			if node.expr:
				_error_node(node, "Beats don't return values. Use 'return' on its own.")
		K.BREAK, K.CONTINUE:
			if not in_loop:
				_error_node(node, "'%s' can only be used inside a loop." % ("break" if node.kind == K.BREAK else "continue"))
		K.BEAT:
			pass # The parser already reports nested beats.


func _declare(node: TaleNode) -> void:
	var scope: Dictionary = _scopes.back()
	if scope.has(node.name):
		_error_node(node, "'%s' is already declared in this block." % node.name)
		return
	for i in range(_scopes.size() - 2, -1, -1):
		if _scopes[i].has(node.name):
			_warn_node(node, "'%s' hides a variable with the same name declared earlier in the beat." % node.name)
			break
	if _story_vars.has(node.name):
		_warn_node(node, "'%s' hides the story variable with the same name." % node.name)
	scope[node.name] = "const" if node.kind == K.CONST else "var"


func _check_speaker(node: TaleNode) -> void:
	if _context.cast.has(node.name):
		var moods: PackedStringArray = _context.cast[node.name]
		if not node.mood.is_empty() and not moods.is_empty() and node.mood not in moods:
			_warn_node(node, "Cast member '%s' has no mood '%s'." % [node.name, node.mood])
		return
	if _lookup(node.name) == "const":
		if not node.mood.is_empty():
			_warn_node(node, "Only cast members have moods; '%s' is a constant." % node.name)
		return
	_error_node(node, "Unknown speaker '%s'. Use a cast member id or a const holding the speaker's name." % node.name)


func _check_text(text: TaleExpr) -> void:
	var result := TaleText.split_interpolation(text.value)
	for message in result["errors"]:
		_error_expr(text, message)
	for part in result["parts"]:
		if part is TaleExpr:
			_check_expr(part, text)
		elif part is Dictionary:
			_check_expr(part["expr"], text)


func _check_jump(node: TaleNode) -> void:
	var parts := node.jump_target.split(".")
	if parts.size() == 1:
		if not _beats.has(parts[0]):
			_error_node(node, "Unknown beat '%s'." % parts[0])
		return
	var tale := parts[0]
	if tale == _context.tale_name:
		if not _beats.has(parts[1]):
			_error_node(node, "Unknown beat '%s'." % parts[1])
	elif not _context.tales.has(tale):
		_error_node(node, "Unknown tale '%s'." % tale)
	elif parts[1] not in _context.tales[tale]["beats"]:
		_error_node(node, "Tale '%s' has no beat '%s'." % [tale, parts[1]])


func _check_assign_target(node: TaleNode) -> void:
	var target := node.target
	if target.kind != E.IDENTIFIER:
		_check_expr(target)
		return
	var kind := _lookup(target.name)
	match kind:
		"var":
			pass
		"const", "builtin_const":
			_error_expr(target, "Can't assign to the constant '%s'." % target.name)
		"":
			_error_expr(target, "Unknown variable '%s'. Declare it first with 'var %s'." % [target.name, target.name])
		_:
			_error_expr(target, "Can't assign to '%s', because it is %s." % [target.name, _describe_kind(kind)])


func _check_match(node: TaleNode, in_loop: bool) -> void:
	var wildcard_seen := false
	var warned := false
	for branch in node.body:
		if branch.kind != K.MATCH_BRANCH:
			continue
		if wildcard_seen and not warned:
			_warn_node(branch, "This branch can never match, because an earlier '_' branch matches everything.")
			warned = true
		for pattern in branch.patterns:
			if pattern.kind == E.IDENTIFIER and pattern.name == "_" and branch.condition == null:
				wildcard_seen = true
	_check_block(node.body, in_loop)


func _check_pattern(pattern: TaleExpr) -> void:
	if pattern.kind == E.IDENTIFIER and pattern.name == "_":
		return
	if pattern.kind not in [E.LITERAL, E.IDENTIFIER, E.ATTRIBUTE, E.UNARY]:
		_error_expr(pattern, "Match patterns must be literals, constants, or '_'.")
		return
	_check_expr(pattern)


func _check_choose(node: TaleNode, in_loop: bool) -> void:
	var has_timeout_argument := false
	if node.expr:
		call_kinds[node.expr] = "choose"
		if not node.expr.args.is_empty():
			_error_expr(node.expr.args[0], "choose only takes named arguments, e.g. choose(style = \"list\").")
		for key in node.expr.named_args:
			_check_expr(node.expr.named_args[key])
			if key == "timeout":
				has_timeout_argument = true
	var options := 0
	var timeouts := 0
	for child in node.body:
		if child.kind == K.OPTION:
			options += 1
		elif child.kind == K.TIMEOUT:
			timeouts += 1
			if timeouts == 2:
				_error_node(child, "A 'choose' block can only have one 'timeout:' branch.")
			if not has_timeout_argument and timeouts == 1:
				_warn_node(child, "'timeout:' only runs when the choose has a timeout, e.g. choose(timeout = 5.0):")
	if options == 0:
		_error_node(node, "A 'choose' block needs at least one option.")
	_check_block(node.body, in_loop)


func _check_annotations(annotations: Array[TaleExpr], node: TaleNode, top_level: bool) -> void:
	var seen := {}
	for annotation in annotations:
		if seen.has(annotation.name):
			_error_expr(annotation, "@%s is used twice on the same line." % annotation.name)
			continue
		seen[annotation.name] = true
		match annotation.name:
			"title":
				_error_expr(annotation, "@title belongs on its own line at the top level of the tale.")
			"global":
				if not (top_level and node.kind == K.VAR):
					_error_expr(annotation, "@global only applies to a 'var' at the top level of the tale.")
				_expect_no_arguments(annotation)
			"once", "show_disabled":
				if node.kind != K.OPTION:
					_error_expr(annotation, "@%s only applies to choice options." % annotation.name)
				_expect_no_arguments(annotation)
			"id":
				if node.kind != K.DIALOGUE and node.kind != K.NARRATION and node.kind != K.OPTION:
					_error_expr(annotation, "@id only applies to dialogue, narration, and choice options.")
				if _expect_one_string(annotation):
					var id: String = annotation.args[0].value
					if _line_ids.has(id):
						_error_expr(annotation, "Line id '%s' is already used on line %d." % [id, _line_ids[id]])
					else:
						_line_ids[id] = annotation.line
			"voice":
				if node.kind != K.DIALOGUE and node.kind != K.NARRATION:
					_error_expr(annotation, "@voice only applies to dialogue and narration lines.")
				_expect_one_string(annotation)
			"no_rewind":
				if top_level:
					_error_expr(annotation, "@no_rewind only applies to lines inside a beat.")
				_expect_no_arguments(annotation)
			"skip_safe":
				if node.kind != K.BEAT:
					_error_expr(annotation, "@skip_safe only applies to beats.")
				_expect_no_arguments(annotation)
			_:
				_error_expr(annotation, "Unknown annotation '@%s'." % annotation.name)


func _expect_no_arguments(annotation: TaleExpr) -> void:
	if not annotation.args.is_empty() or not annotation.named_args.is_empty():
		_error_expr(annotation, "@%s takes no arguments." % annotation.name)


func _expect_one_string(annotation: TaleExpr) -> bool:
	var valid := annotation.args.size() == 1 and annotation.named_args.is_empty() \
		and annotation.args[0].kind == E.LITERAL and annotation.args[0].value is String
	if not valid:
		_error_expr(annotation, "@%s needs one text argument, e.g. @%s(\"...\")." % [annotation.name, annotation.name])
	return valid


func _report_unused_annotations(pending: Array[TaleExpr]) -> void:
	for annotation in pending:
		_error_expr(annotation, "@%s is not followed by a line it can apply to." % annotation.name)


# --- Expressions ------------------------------------------------------------

## Checks names and calls in [param expr]. [param anchor] is the expression
## whose position is reported, used for values interpolated into text.
func _check_expr(expr: TaleExpr, anchor: TaleExpr = null) -> void:
	match expr.kind:
		E.LITERAL:
			pass
		E.IDENTIFIER:
			_check_value_name(expr, anchor)
		E.CALL:
			_check_call(expr, anchor)
		E.ATTRIBUTE:
			var base := expr.operands[0]
			var base_kind := _lookup(base.name) if base.kind == E.IDENTIFIER else ""
			if base_kind == "tale":
				_check_tale_member(base.name, expr.name, false, expr, anchor)
			elif base_kind == "cast":
				if expr.name not in _context.get_cast_members(base.name):
					_error_expr(expr, "Cast member '%s' has no '%s'. Its fields come from the cast profile." % [base.name, expr.name], anchor)
			elif base_kind != "constructor":
				_check_expr(base, anchor)
		_:
			for operand in expr.operands:
				_check_expr(operand, anchor)


func _check_value_name(expr: TaleExpr, anchor: TaleExpr) -> void:
	var kind := _lookup(expr.name)
	match kind:
		"":
			_error_expr(expr, "Unknown name '%s'." % expr.name, anchor)
		"beat":
			_error_expr(expr, "'%s' is a beat. Call it with %s() or use 'jump %s'." % [expr.name, expr.name, expr.name], anchor)
		"action", "function", "constructor":
			_error_expr(expr, "'%s' is %s. Call it with %s(...)." % [expr.name, _describe_kind(kind), expr.name], anchor)
		"tale":
			_error_expr(expr, "'%s' is a tale. Refer to one of its beats or variables, e.g. %s.start." % [expr.name, expr.name], anchor)


func _check_call(expr: TaleExpr, anchor: TaleExpr) -> void:
	for argument in expr.args:
		_check_expr(argument, anchor)
	for key in expr.named_args:
		_check_expr(expr.named_args[key], anchor)

	var callee := expr.operands[0]
	if callee.kind == E.ATTRIBUTE and callee.operands[0].kind == E.IDENTIFIER \
			and _lookup(callee.operands[0].name) == "tale":
		call_kinds[expr] = "tale_beat"
		_check_tale_member(callee.operands[0].name, callee.name, true, expr, anchor)
		_expect_no_call_arguments(expr, anchor)
		return
	if callee.kind != E.IDENTIFIER:
		call_kinds[expr] = "method"
		_check_expr(callee, anchor)
		return

	var kind := _lookup(callee.name)
	match kind:
		"beat":
			call_kinds[expr] = "beat"
			_expect_no_call_arguments(expr, anchor)
		"action":
			call_kinds[expr] = "action"
			_check_action_arguments(expr, callee.name, anchor)
		"function", "constructor":
			call_kinds[expr] = kind
			if not expr.named_args.is_empty():
				_error_expr(expr, "'%s' does not take named arguments." % callee.name, anchor)
		"exposed":
			call_kinds[expr] = "exposed"
		"":
			_error_expr(callee, "Unknown action or beat '%s'." % callee.name, anchor)
		_:
			_error_expr(callee, "'%s' is %s and can't be called." % [callee.name, _describe_kind(kind)], anchor)


func _expect_no_call_arguments(expr: TaleExpr, anchor: TaleExpr) -> void:
	if not expr.args.is_empty() or not expr.named_args.is_empty():
		_error_expr(expr, "Beats don't take arguments.", anchor)


func _check_action_arguments(expr: TaleExpr, action: String, anchor: TaleExpr) -> void:
	var signature: Variant = _context.actions[action]
	if signature == null:
		return
	var params: PackedStringArray = signature["params"]
	var required: int = signature["required"]
	if expr.args.size() > params.size():
		_error_expr(expr, "'%s' takes at most %d arguments, but %d were given." % [action, params.size(), expr.args.size()], anchor)
	for key in expr.named_args:
		var index := params.find(key)
		if index == -1:
			_error_expr(expr.named_args[key], "'%s' has no argument named '%s'." % [action, key], anchor)
		elif index < expr.args.size():
			_error_expr(expr.named_args[key], "Argument '%s' is already given by position." % key, anchor)
	for i in range(expr.args.size(), mini(required, params.size())):
		if not expr.named_args.has(params[i]):
			_error_expr(expr, "'%s' needs the argument '%s'." % [action, params[i]], anchor)


func _check_tale_member(tale: String, member: String, is_call: bool, expr: TaleExpr, anchor: TaleExpr) -> void:
	var beats: Array = []
	var vars: Array = []
	if tale == _context.tale_name:
		beats = _beats.keys()
		vars = _story_vars.keys()
	else:
		beats = Array(_context.tales[tale]["beats"])
		vars = Array(_context.tales[tale]["vars"])
	if is_call and member not in beats:
		_error_expr(expr, "Tale '%s' has no beat '%s'." % [tale, member], anchor)
	elif not is_call and member not in vars:
		_error_expr(expr, "Tale '%s' has no variable '%s'." % [tale, member], anchor)


## Returns what [param name] refers to: "var", "const", "builtin_const",
## "cast", "exposed", "beat", "action", "function", "constructor", "tale",
## or "" when unknown. Inner scopes win over outer ones.
func _lookup(name: String) -> String:
	for i in range(_scopes.size() - 1, -1, -1):
		if _scopes[i].has(name):
			return _scopes[i][name]
	if _story_vars.has(name):
		return "const" if _story_vars[name].kind == K.CONST else "var"
	if name in TaleCheckContext.BUILTIN_CONSTANTS:
		return "builtin_const"
	if _context.cast.has(name):
		return "cast"
	if _context.exposed.has(name):
		return "exposed"
	if _beats.has(name):
		return "beat"
	if _context.actions.has(name):
		return "action"
	if name in TaleCheckContext.BUILTIN_FUNCTIONS:
		return "function"
	if name in TaleCheckContext.CONSTRUCTORS:
		return "constructor"
	if name == _context.tale_name or _context.tales.has(name):
		return "tale"
	return ""


static func _describe_kind(kind: String) -> String:
	match kind:
		"cast":
			return "a cast member"
		"exposed":
			return "an object from game code"
		"beat":
			return "a beat"
		"action":
			return "an action"
		"function":
			return "a built-in function"
		"constructor":
			return "a type"
		"tale":
			return "a tale"
		"var":
			return "a variable"
	return "a constant"


# --- Reporting ----------------------------------------------------------------

static func _merge(first: Array[TaleExpr], second: Array[TaleExpr]) -> Array[TaleExpr]:
	var merged: Array[TaleExpr] = []
	merged.append_array(first)
	merged.append_array(second)
	return merged


func _error_node(node: TaleNode, message: String) -> void:
	_add(TaleDiagnostic.Severity.ERROR, message, node.line_start, node.indent.length() + 1)


func _warn_node(node: TaleNode, message: String) -> void:
	_add(TaleDiagnostic.Severity.WARNING, message, node.line_start, node.indent.length() + 1)


func _error_expr(expr: TaleExpr, message: String, anchor: TaleExpr = null) -> void:
	var at := anchor if anchor != null else expr
	_add(TaleDiagnostic.Severity.ERROR, message, at.line, at.column)


func _add(severity: TaleDiagnostic.Severity, message: String, line: int, column: int) -> void:
	_diagnostics.append(TaleDiagnostic.new(severity, message, line, column))

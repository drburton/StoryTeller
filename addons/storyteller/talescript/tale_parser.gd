class_name TaleParser
extends RefCounted
## Parses TaleScript source into a [TaleDocument].
##
## Parsing never stops at the first problem. A line that cannot be parsed
## becomes an ERROR node, and parsing continues with the next line, so editors
## can show every error at once and the tree still covers the whole file.

const ASSIGN_OPS: Array[String] = ["=", "+=", "-=", "*=", "/=", "%=", "**=", "&=", "|=", "^=", "<<=", ">>="]

## Binary operator precedence, following GDScript. Higher binds tighter.
const BINARY_PRECEDENCE := {
	"or": 2, "||": 2,
	"and": 3, "&&": 3,
	"in": 5, "not in": 5,
	"<": 6, ">": 6, "<=": 6, ">=": 6, "==": 6, "!=": 6,
	"|": 7, "^": 8, "&": 9, "<<": 10, ">>": 10,
	"+": 11, "-": 11,
	"*": 12, "/": 12, "%": 12,
	"**": 15,
}
const PREC_TERNARY := 1
const PREC_NOT := 4
const PREC_UNARY := 13
const PREC_BIT_NOT := 14
const PREC_AWAIT := 16

## What a block may contain.
enum Context { TOP, BLOCK, MATCH, CHOOSE }


class _Line:
	var tokens: Array[TaleToken] = []
	var comment: TaleToken
	var start := 0
	var end := 0
	var indent := ""


class _Frame:
	var indent: String
	var body: Array[TaleNode]
	var context: Context

	func _init(p_indent: String, p_body: Array[TaleNode], p_context: Context) -> void:
		indent = p_indent
		body = p_body
		context = p_context


var _doc: TaleDocument
var _tokens: Array[TaleToken] = []
var _index := 0
var _end_token: TaleToken
var _failed := false
var _fail_message := ""
var _fail_token: TaleToken
var _indent_char := ""


## Parses [param source]. [param path] is only used for messages and lookups.
static func parse(source: String, path := "") -> TaleDocument:
	return TaleParser.new()._parse(source, path)


func _parse(source: String, path: String) -> TaleDocument:
	_doc = TaleDocument.new()
	_doc.path = path
	_doc.lines = source.split("\n")
	var lexer := TaleLexer.new()
	var tokens := lexer.tokenize(source)
	_doc.diagnostics.append_array(lexer.diagnostics)

	var stack: Array[_Frame] = [_Frame.new("", _doc.statements, Context.TOP)]
	var pending: TaleNode = null
	var trivia: Array[TaleNode] = []

	for line in _logical_lines(tokens):
		if line.tokens.is_empty():
			trivia.append(_trivia_node(line))
			continue
		_check_indent_chars(line)

		var opened := false
		if pending != null:
			var top := stack.back() as _Frame
			if line.indent.length() > top.indent.length() and line.indent.begins_with(top.indent):
				stack.append(_Frame.new(line.indent, pending.body, _body_context(pending)))
				opened = true
			elif pending.kind != TaleNode.Kind.ERROR:
				_error("Expected an indented block after '%s'." % _header_label(pending), line.start, 1)
			pending = null

		var deepest := stack.back() as _Frame
		if not opened:
			if line.indent.length() > deepest.indent.length():
				_error("Unexpected indentation.", line.start, 1)
			elif line.indent != deepest.indent:
				var last_popped: _Frame = null
				while stack.size() > 1 and (stack.back() as _Frame).indent.length() > line.indent.length():
					last_popped = stack.pop_back()
				if (stack.back() as _Frame).indent != line.indent:
					_error("Indentation does not match any outer block.", line.start, 1)
					# Keep the line in the closest block it was meant for.
					if last_popped != null:
						stack.append(last_popped)

		var frame := stack.back() as _Frame
		_place_trivia(trivia, deepest, frame, line.indent)
		var node := _parse_line(line, frame.context)
		frame.body.append(node)
		var opens_block: bool = node.is_block() or (node.kind == TaleNode.Kind.ERROR and line.tokens.back().is_op(":"))
		if opens_block and node.body.is_empty():
			pending = node

	if pending != null and pending.kind != TaleNode.Kind.ERROR:
		_error("Expected an indented block after '%s'." % _header_label(pending), pending.line_end, 1)
	_place_trivia(trivia, stack.back(), stack[0], "")
	_doc.diagnostics.sort_custom(func(a: TaleDiagnostic, b: TaleDiagnostic) -> bool:
		return a.line < b.line or (a.line == b.line and a.column < b.column))
	return _doc


# --- Lines and blocks -------------------------------------------------------

## Groups tokens into logical lines. Every content line of the source ends up
## in exactly one logical line.
func _logical_lines(tokens: Array[TaleToken]) -> Array[_Line]:
	var content_lines := _doc.lines.size()
	if content_lines > 0 and _doc.lines[content_lines - 1] == "":
		content_lines -= 1
	var result: Array[_Line] = []
	var current := _Line.new()
	var previous_end := 0
	for token in tokens:
		match token.type:
			TaleToken.Type.NEWLINE, TaleToken.Type.END:
				var last := token.line
				if token.type == TaleToken.Type.END:
					if previous_end >= content_lines:
						break
					last = content_lines
				current.start = previous_end + 1
				current.end = last
				current.indent = _leading_whitespace(_doc.lines[current.start - 1])
				result.append(current)
				previous_end = last
				current = _Line.new()
			TaleToken.Type.COMMENT:
				if current.comment == null:
					current.comment = token
			_:
				current.tokens.append(token)
	return result


func _trivia_node(line: _Line) -> TaleNode:
	var node := TaleNode.new(TaleNode.Kind.COMMENT if line.comment else TaleNode.Kind.BLANK)
	node.line_start = line.start
	node.line_end = line.end
	node.indent = line.indent
	if line.comment:
		node.comment = line.comment.value
	return node


## Puts buffered blank and comment lines into a block. When the next statement
## closes blocks, comments indented deeper than it stay with the inner block.
func _place_trivia(trivia: Array[TaleNode], deepest: _Frame, frame: _Frame, indent: String) -> void:
	var split := 0
	if deepest != frame:
		for i in trivia.size():
			if trivia[i].kind == TaleNode.Kind.COMMENT and trivia[i].indent.length() > indent.length():
				split = i + 1
	for i in trivia.size():
		(deepest if i < split else frame).body.append(trivia[i])
	trivia.clear()


func _check_indent_chars(line: _Line) -> void:
	if line.indent.is_empty():
		return
	if " " in line.indent and "\t" in line.indent:
		_error("Mixed tabs and spaces in indentation.", line.start, 1)
		return
	var used := line.indent[0]
	if _indent_char.is_empty():
		_indent_char = used
	elif used != _indent_char:
		var expected := "tabs" if _indent_char == "\t" else "spaces"
		_error("Indentation uses %s elsewhere in this file." % expected, line.start, 1)


func _body_context(header: TaleNode) -> Context:
	match header.kind:
		TaleNode.Kind.MATCH:
			return Context.MATCH
		TaleNode.Kind.CHOOSE:
			return Context.CHOOSE
	return Context.BLOCK


func _header_label(header: TaleNode) -> String:
	match header.kind:
		TaleNode.Kind.BEAT:
			return "beat %s" % header.name
		TaleNode.Kind.MATCH_BRANCH:
			return "match branch"
		TaleNode.Kind.OPTION:
			return "choice option"
	return (TaleNode.Kind.keys()[header.kind] as String).to_lower()


static func _leading_whitespace(text: String) -> String:
	var i := 0
	while i < text.length() and (text[i] == " " or text[i] == "\t"):
		i += 1
	return text.substr(0, i)


# --- Statements -------------------------------------------------------------

func _parse_line(line: _Line, context: Context) -> TaleNode:
	_tokens = line.tokens
	_index = 0
	_failed = false
	_fail_message = ""
	_fail_token = null
	var last := line.tokens.back() as TaleToken
	_end_token = TaleToken.new(TaleToken.Type.NEWLINE, "end of line", null, last.line, last.column + last.text.length())

	var node: TaleNode = null
	var lexer_error := false
	for token in line.tokens:
		if token.type == TaleToken.Type.ERROR:
			lexer_error = true
			node = _error_node(token.value)
			break
	if not lexer_error:
		node = _statement(context, false)
		if not _failed and not _at_end():
			_fail("Unexpected '%s'." % _peek().text)
		if _failed:
			_error(_fail_message, _fail_token.line, _fail_token.column)
			node = _error_node(_fail_message)

	node.line_start = line.start
	node.line_end = line.end
	node.indent = line.indent
	if line.comment:
		node.comment = line.comment.value
	for child in node.body:
		child.line_start = line.start
		child.line_end = line.end
		child.indent = line.indent
	return node


func _error_node(message: String) -> TaleNode:
	var node := TaleNode.new(TaleNode.Kind.ERROR)
	node.message = message
	return node


func _statement(context: Context, inline: bool) -> TaleNode:
	var annotations := _annotations()
	if _failed:
		return null
	if _at_end():
		if inline:
			_fail("Expected a statement after ':'.")
			return null
		var holder := TaleNode.new(TaleNode.Kind.ANNOTATION)
		holder.annotations = annotations
		return holder

	var node: TaleNode
	match context:
		Context.TOP:
			node = _top_statement()
		Context.MATCH:
			node = _match_branch()
		Context.CHOOSE:
			node = _choose_option()
		_:
			node = _block_statement()
	if _failed:
		return null
	node.annotations = annotations

	if node.is_block() and not _at_end():
		if inline:
			_fail("Only one block header is allowed per line.")
			return null
		if node.kind == TaleNode.Kind.MATCH or node.kind == TaleNode.Kind.CHOOSE:
			_fail("Start a new line after '%s:'." % _header_label(node))
			return null
		var child := _statement(Context.BLOCK, true)
		if _failed:
			return null
		if child.is_block():
			_fail("A block can't start on the same line as another block.")
			return null
		child.inline = true
		node.body.append(child)
	return node


func _annotations() -> Array[TaleExpr]:
	var result: Array[TaleExpr] = []
	while not _failed and _peek().type == TaleToken.Type.ANNOTATION:
		var token := _advance()
		var annotation := TaleExpr.new(TaleExpr.Kind.ANNOTATION, token.line, token.column)
		annotation.name = token.value
		if _peek().is_op("("):
			_advance()
			_call_arguments(annotation)
		result.append(annotation)
	return result


func _top_statement() -> TaleNode:
	var token := _peek()
	if token.is_keyword("var"):
		return _var_declaration()
	if token.is_keyword("const"):
		return _const_declaration()
	if token.is_keyword("beat"):
		return _beat()
	_fail("Only 'var', 'const', and 'beat' are allowed here. Put story lines inside a beat.")
	return null


func _block_statement() -> TaleNode:
	var token := _peek()
	if token.type == TaleToken.Type.KEYWORD:
		match token.value:
			"var":
				return _var_declaration()
			"const":
				return _const_declaration()
			"beat":
				_fail("Beats can't be nested. Declare 'beat %s' at the top level of the file." % _peek_at(1).text)
				return null
			"if", "elif", "while":
				return _conditional_header()
			"else":
				_advance()
				var else_node := TaleNode.new(TaleNode.Kind.ELSE)
				_expect_op(":", "after 'else'")
				return else_node
			"for":
				return _for_loop()
			"match":
				_advance()
				var match_node := TaleNode.new(TaleNode.Kind.MATCH)
				match_node.expr = _expression()
				_expect_op(":", "after the match value")
				return match_node
			"choose":
				return _choose()
			"jump":
				return _jump()
			"return":
				_advance()
				var return_node := TaleNode.new(TaleNode.Kind.RETURN)
				if not _at_end():
					return_node.expr = _expression()
				return return_node
			"pass", "break", "continue":
				_advance()
				return TaleNode.new(TaleNode.Kind[(token.value as String).to_upper()])
	if token.type == TaleToken.Type.STRING:
		var next := _peek_at(1)
		if next.type == TaleToken.Type.NEWLINE:
			_advance()
			var narration := TaleNode.new(TaleNode.Kind.NARRATION)
			narration.expr = _literal(token)
			return narration
		if next.is_op(":") or next.is_keyword("if"):
			_fail("Choice options belong inside a 'choose:' block.")
			return null
	if token.type == TaleToken.Type.IDENTIFIER and _is_dialogue():
		return _dialogue()
	return _expression_statement()


func _var_declaration() -> TaleNode:
	_advance()
	var node := TaleNode.new(TaleNode.Kind.VAR)
	node.name = _expect_identifier("variable name")
	if _peek().is_op(":"):
		_advance()
		node.type_hint = _type_hint()
	if _peek().is_op(":="):
		_advance()
		node.infer_type = true
		node.expr = _expression()
	elif _peek().is_op("="):
		_advance()
		node.expr = _expression()
	return node


func _const_declaration() -> TaleNode:
	_advance()
	var node := TaleNode.new(TaleNode.Kind.CONST)
	node.name = _expect_identifier("constant name")
	if _peek().is_op(":"):
		_advance()
		node.type_hint = _type_hint()
	if _peek().is_op(":="):
		_advance()
		node.infer_type = true
	elif not _expect_op("=", "and a value for the constant"):
		return node
	node.expr = _expression()
	return node


func _type_hint() -> String:
	var type_name := _expect_identifier("type name")
	if _peek().is_op("["):
		_advance()
		type_name += "[%s]" % _expect_identifier("type name")
		_expect_op("]", "to close the type")
	return type_name


func _beat() -> TaleNode:
	_advance()
	var node := TaleNode.new(TaleNode.Kind.BEAT)
	node.name = _expect_identifier("beat name")
	if _peek().is_op("("):
		_fail("Beats don't take parameters. Use variables to pass values.")
		return node
	_expect_op(":", "after the beat name")
	return node


func _conditional_header() -> TaleNode:
	var keyword := _advance()
	var node := TaleNode.new(TaleNode.Kind[(keyword.value as String).to_upper()])
	node.expr = _expression()
	_expect_op(":", "after the condition")
	return node


func _for_loop() -> TaleNode:
	_advance()
	var node := TaleNode.new(TaleNode.Kind.FOR)
	node.name = _expect_identifier("loop variable")
	if _peek().is_op(":"):
		_advance()
		node.type_hint = _type_hint()
	_expect_keyword("in", "after the loop variable")
	node.expr = _expression()
	_expect_op(":", "after the loop")
	return node


func _choose() -> TaleNode:
	var keyword := _advance()
	var node := TaleNode.new(TaleNode.Kind.CHOOSE)
	if _peek().is_op("("):
		_advance()
		var call := TaleExpr.new(TaleExpr.Kind.CALL, keyword.line, keyword.column)
		var callee := TaleExpr.new(TaleExpr.Kind.IDENTIFIER, keyword.line, keyword.column)
		callee.name = "choose"
		call.operands.append(callee)
		_call_arguments(call)
		node.expr = call
	_expect_op(":", "after 'choose'")
	return node


func _jump() -> TaleNode:
	_advance()
	var node := TaleNode.new(TaleNode.Kind.JUMP)
	node.jump_target = _expect_identifier("beat name after 'jump'")
	if _peek().is_op("."):
		_advance()
		node.jump_target += "." + _expect_identifier("beat name after '.'")
	return node


## True when the line starts with [code]name:[/code] or [code]name (mood):[/code].
func _is_dialogue() -> bool:
	var i := _index + 1
	if _peek_at(1).is_op("("):
		var depth := 0
		while i < _tokens.size():
			if _tokens[i].is_op("("):
				depth += 1
			elif _tokens[i].is_op(")"):
				depth -= 1
				if depth == 0:
					break
			i += 1
		i += 1
	return i < _tokens.size() and _tokens[i].is_op(":")


func _dialogue() -> TaleNode:
	var node := TaleNode.new(TaleNode.Kind.DIALOGUE)
	node.name = _advance().value
	if _peek().is_op("("):
		_advance()
		var mood := _advance()
		if mood.type != TaleToken.Type.IDENTIFIER and mood.type != TaleToken.Type.STRING:
			_fail("Expected a mood name inside the parentheses.", mood)
			return node
		node.mood = mood.value
		_expect_op(")", "after the mood")
	_expect_op(":", "after the speaker")
	if _failed:
		return node
	var text := _peek()
	if text.type != TaleToken.Type.STRING:
		_fail("Dialogue text must be a quoted string, e.g. %s: \"Hello\"." % node.name, text)
		return node
	_advance()
	node.expr = _literal(text)
	return node


func _expression_statement() -> TaleNode:
	var value := _expression()
	if _failed:
		return null
	var next := _peek()
	if next.type == TaleToken.Type.OPERATOR and next.value in ASSIGN_OPS:
		if value.kind not in [TaleExpr.Kind.IDENTIFIER, TaleExpr.Kind.ATTRIBUTE, TaleExpr.Kind.INDEX]:
			_fail("Can't assign to this expression.", next)
			return null
		_advance()
		var node := TaleNode.new(TaleNode.Kind.ASSIGN)
		node.target = value
		node.op = next.value
		node.expr = _expression()
		return node
	if next.is_op(":"):
		_fail("Unexpected ':'. Dialogue lines look like: name: \"text\".", next)
		return null
	var statement := TaleNode.new(TaleNode.Kind.EXPRESSION)
	statement.expr = value
	return statement


func _match_branch() -> TaleNode:
	var node := TaleNode.new(TaleNode.Kind.MATCH_BRANCH)
	if _peek().is_keyword("var"):
		_fail("Binding patterns ('var name') are not supported yet.")
		return node
	node.patterns.append(_expression())
	while not _failed and _peek().is_op(","):
		_advance()
		node.patterns.append(_expression())
	if _peek().is_keyword("when"):
		_advance()
		node.condition = _expression()
	_expect_op(":", "after the match pattern")
	return node


func _choose_option() -> TaleNode:
	var token := _peek()
	if token.type == TaleToken.Type.IDENTIFIER and token.value == "timeout" and _peek_at(1).is_op(":"):
		_advance()
		_advance()
		return TaleNode.new(TaleNode.Kind.TIMEOUT)
	if token.type != TaleToken.Type.STRING:
		_fail("Expected a choice option, e.g. \"Open the door\":")
		return null
	_advance()
	var node := TaleNode.new(TaleNode.Kind.OPTION)
	node.expr = _literal(token)
	if _peek().is_keyword("if"):
		_advance()
		node.condition = _expression()
	_expect_op(":", "after the option text")
	return node


# --- Expressions ------------------------------------------------------------

func _expression(min_precedence := 0) -> TaleExpr:
	var left := _unary()
	while not _failed and not _at_end():
		var token := _peek()
		var op := _binary_operator()
		if op != "":
			var precedence: int = BINARY_PRECEDENCE[op]
			if precedence < min_precedence:
				break
			_advance()
			if op == "not in":
				_advance()
			var binary := TaleExpr.new(TaleExpr.Kind.BINARY, left.line, left.column)
			binary.op = _normalize_operator(op)
			binary.operands.append(left)
			binary.operands.append(_expression(precedence + 1))
			left = binary
		elif token.is_keyword("if") and PREC_TERNARY >= min_precedence:
			_advance()
			var ternary := TaleExpr.new(TaleExpr.Kind.TERNARY, left.line, left.column)
			var condition := _expression(PREC_TERNARY + 1)
			_expect_keyword("else", "in the conditional expression")
			ternary.operands.append(left)
			ternary.operands.append(condition)
			ternary.operands.append(_expression(PREC_TERNARY))
			left = ternary
		else:
			break
	return left


func _binary_operator() -> String:
	var token := _peek()
	if token.type == TaleToken.Type.OPERATOR and BINARY_PRECEDENCE.has(token.value):
		return token.value
	if token.type == TaleToken.Type.KEYWORD:
		if token.value in ["and", "or", "in"]:
			return token.value
		if token.value == "not" and _peek_at(1).is_keyword("in"):
			return "not in"
	return ""


static func _normalize_operator(op: String) -> String:
	match op:
		"&&":
			return "and"
		"||":
			return "or"
		"!":
			return "not"
	return op


func _unary() -> TaleExpr:
	var token := _peek()
	var precedence := -1
	var kind := TaleExpr.Kind.UNARY
	if token.is_op("-") or token.is_op("+"):
		precedence = PREC_UNARY
	elif token.is_op("~"):
		precedence = PREC_BIT_NOT
	elif token.is_keyword("not") or token.is_op("!"):
		precedence = PREC_NOT
	elif token.is_keyword("await"):
		precedence = PREC_AWAIT
		kind = TaleExpr.Kind.AWAIT
	if precedence < 0:
		return _postfix(_primary())
	_advance()
	var unary := TaleExpr.new(kind, token.line, token.column)
	unary.op = _normalize_operator(token.value)
	unary.operands.append(_expression(precedence))
	return unary


func _primary() -> TaleExpr:
	var token := _advance()
	match token.type:
		TaleToken.Type.INT, TaleToken.Type.FLOAT, TaleToken.Type.STRING:
			return _literal(token)
		TaleToken.Type.IDENTIFIER:
			var identifier := TaleExpr.new(TaleExpr.Kind.IDENTIFIER, token.line, token.column)
			identifier.name = token.value
			return identifier
		TaleToken.Type.KEYWORD:
			match token.value:
				"true":
					return _literal_value(token, true)
				"false":
					return _literal_value(token, false)
				"null":
					return _literal_value(token, null)
		TaleToken.Type.OPERATOR:
			match token.value:
				"(":
					var inner := _expression()
					_expect_op(")", "to close '('")
					return inner
				"[":
					return _array(token)
				"{":
					return _dictionary(token)
	if token.type == TaleToken.Type.NEWLINE:
		_fail("Expected an expression, but the line ended.", token)
	else:
		_fail("Expected an expression, found '%s'." % token.text, token)
	return TaleExpr.new(TaleExpr.Kind.LITERAL, token.line, token.column)


func _postfix(base: TaleExpr) -> TaleExpr:
	var result := base
	while not _failed:
		var token := _peek()
		if token.is_op("("):
			_advance()
			var call := TaleExpr.new(TaleExpr.Kind.CALL, result.line, result.column)
			call.operands.append(result)
			_call_arguments(call)
			result = call
		elif token.is_op("."):
			_advance()
			var attribute := TaleExpr.new(TaleExpr.Kind.ATTRIBUTE, result.line, result.column)
			attribute.operands.append(result)
			attribute.name = _expect_identifier("name after '.'")
			result = attribute
		elif token.is_op("["):
			_advance()
			var index := TaleExpr.new(TaleExpr.Kind.INDEX, result.line, result.column)
			index.operands.append(result)
			index.operands.append(_expression())
			_expect_op("]", "to close '['")
			result = index
		else:
			break
	return result


## Parses arguments after '(' up to and including ')'.
func _call_arguments(call: TaleExpr) -> void:
	while not _failed and not _peek().is_op(")"):
		var token := _peek()
		if token.type == TaleToken.Type.IDENTIFIER and _peek_at(1).is_op("="):
			_advance()
			_advance()
			if call.named_args.has(token.value):
				_fail("Argument '%s' is given twice." % token.value, token)
				return
			call.named_args[token.value] = _expression()
		else:
			if not call.named_args.is_empty():
				_fail("Positional arguments must come before named arguments.", token)
				return
			call.args.append(_expression())
		if not _peek().is_op(","):
			break
		_advance()
	_expect_op(")", "to close the argument list")


func _array(open: TaleToken) -> TaleExpr:
	var array := TaleExpr.new(TaleExpr.Kind.ARRAY, open.line, open.column)
	while not _failed and not _peek().is_op("]"):
		array.operands.append(_expression())
		if not _peek().is_op(","):
			break
		_advance()
	_expect_op("]", "to close the array")
	return array


func _dictionary(open: TaleToken) -> TaleExpr:
	var dictionary := TaleExpr.new(TaleExpr.Kind.DICTIONARY, open.line, open.column)
	while not _failed and not _peek().is_op("}"):
		var token := _peek()
		if token.type == TaleToken.Type.IDENTIFIER and _peek_at(1).is_op("="):
			_advance()
			_advance()
			dictionary.operands.append(_literal_value(token, token.value))
		else:
			dictionary.operands.append(_expression())
			_expect_op(":", "after the dictionary key")
		dictionary.operands.append(_expression())
		if not _peek().is_op(","):
			break
		_advance()
	_expect_op("}", "to close the dictionary")
	return dictionary


func _literal(token: TaleToken) -> TaleExpr:
	return _literal_value(token, token.value)


func _literal_value(token: TaleToken, value: Variant) -> TaleExpr:
	var literal := TaleExpr.new(TaleExpr.Kind.LITERAL, token.line, token.column)
	literal.value = value
	return literal


# --- Token helpers ----------------------------------------------------------

func _peek() -> TaleToken:
	return _tokens[_index] if _index < _tokens.size() else _end_token


func _peek_at(offset: int) -> TaleToken:
	var i := _index + offset
	return _tokens[i] if i < _tokens.size() else _end_token


func _advance() -> TaleToken:
	var token := _peek()
	if _index < _tokens.size():
		_index += 1
	return token


func _at_end() -> bool:
	return _index >= _tokens.size()


func _expect_op(op: String, context: String) -> bool:
	if _failed:
		return false
	if _peek().is_op(op):
		_advance()
		return true
	_fail("Expected '%s' %s, found %s." % [op, context, _describe(_peek())])
	return false


func _expect_keyword(word: String, context: String) -> bool:
	if _failed:
		return false
	if _peek().is_keyword(word):
		_advance()
		return true
	_fail("Expected '%s' %s, found %s." % [word, context, _describe(_peek())])
	return false


func _expect_identifier(what: String) -> String:
	if _failed:
		return ""
	var token := _peek()
	if token.type == TaleToken.Type.IDENTIFIER:
		_advance()
		return token.value
	if token.type == TaleToken.Type.KEYWORD:
		_fail("'%s' is a reserved word and can't be used as a %s." % [token.text, what])
	else:
		_fail("Expected a %s, found %s." % [what, _describe(token)])
	return ""


static func _describe(token: TaleToken) -> String:
	if token.type == TaleToken.Type.NEWLINE:
		return "the end of the line"
	return "'%s'" % token.text


func _fail(message: String, token: TaleToken = null) -> void:
	if _failed:
		return
	_failed = true
	_fail_message = message
	_fail_token = token if token != null else _peek()


func _error(message: String, line: int, column: int) -> void:
	_doc.diagnostics.append(TaleDiagnostic.new(TaleDiagnostic.Severity.ERROR, message, line, column))

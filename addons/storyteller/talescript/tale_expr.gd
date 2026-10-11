class_name TaleExpr
extends RefCounted
## An expression in a tale, such as [code]trust + 1[/code] or
## [code]mira.move_to(CENTER, time = 0.6)[/code].

enum Kind {
	LITERAL,
	IDENTIFIER,
	UNARY,
	BINARY,
	TERNARY,
	AWAIT,
	CALL,
	ATTRIBUTE,
	INDEX,
	ARRAY,
	DICTIONARY,
	ANNOTATION,
}

var kind: Kind
## Value of a LITERAL.
var value: Variant
## Name of an IDENTIFIER, ATTRIBUTE, or ANNOTATION.
var name := ""
## Operator of a UNARY or BINARY expression, e.g. [code]"+"[/code] or [code]"not in"[/code].
var op := ""
## Sub-expressions. UNARY and AWAIT: [operand]. BINARY: [left, right].
## TERNARY: [if_true, condition, if_false]. CALL: [callee]. ATTRIBUTE: [object].
## INDEX: [object, index]. ARRAY: items. DICTIONARY: alternating keys and values.
var operands: Array[TaleExpr] = []
## Positional arguments of a CALL or ANNOTATION.
var args: Array[TaleExpr] = []
## Named arguments of a CALL or ANNOTATION, in source order.
var named_args: Dictionary[String, TaleExpr] = {}
## 1-based position of the expression's first token.
var line := 0
var column := 0


func _init(p_kind: Kind, p_line := 0, p_column := 0) -> void:
	kind = p_kind
	line = p_line
	column = p_column


## Returns the callee name of a call to a plain identifier, or "".
func get_call_name() -> String:
	if kind == Kind.CALL and operands[0].kind == Kind.IDENTIFIER:
		return operands[0].name
	return ""


## Returns a compact, unambiguous text form, used by tests and debugging.
func to_sexpr() -> String:
	match kind:
		Kind.LITERAL:
			return _literal_text(value)
		Kind.IDENTIFIER:
			return name
		Kind.UNARY:
			return "(%s %s)" % [op, operands[0].to_sexpr()]
		Kind.AWAIT:
			return "(await %s)" % operands[0].to_sexpr()
		Kind.BINARY:
			return "(%s %s %s)" % [op, operands[0].to_sexpr(), operands[1].to_sexpr()]
		Kind.TERNARY:
			return "(if %s %s %s)" % [operands[1].to_sexpr(), operands[0].to_sexpr(), operands[2].to_sexpr()]
		Kind.CALL:
			var parts := PackedStringArray([operands[0].to_sexpr()])
			parts.append_array(_arg_texts())
			return "(call %s)" % " ".join(parts)
		Kind.ANNOTATION:
			var texts := _arg_texts()
			return "@%s" % name if texts.is_empty() else "@%s(%s)" % [name, " ".join(texts)]
		Kind.ATTRIBUTE:
			return "(. %s %s)" % [operands[0].to_sexpr(), name]
		Kind.INDEX:
			return "([] %s %s)" % [operands[0].to_sexpr(), operands[1].to_sexpr()]
		Kind.ARRAY:
			var items := PackedStringArray()
			for item in operands:
				items.append(item.to_sexpr())
			return "[%s]" % " ".join(items)
		Kind.DICTIONARY:
			var entries := PackedStringArray()
			for i in range(0, operands.size(), 2):
				entries.append("%s: %s" % [operands[i].to_sexpr(), operands[i + 1].to_sexpr()])
			return "{%s}" % ", ".join(entries)
	return "?"


## Returns TaleScript source for this expression, with parentheses only
## where precedence needs them. Used by the visual editor to rewrite a
## statement after one of its fields changes.
func to_source() -> String:
	return _source(0)


## Quotes [param text] as a TaleScript string literal.
static func quote(text: String) -> String:
	var escaped := text.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")
	return "\"%s\"" % escaped


## Binding strength of this expression, as in [TaleParser].
func precedence() -> int:
	match kind:
		Kind.BINARY:
			return TaleParser.BINARY_PRECEDENCE.get(op, 0)
		Kind.TERNARY:
			return TaleParser.PREC_TERNARY
		Kind.UNARY:
			if op == "not":
				return TaleParser.PREC_NOT
			return TaleParser.PREC_BIT_NOT if op == "~" else TaleParser.PREC_UNARY
		Kind.AWAIT:
			return TaleParser.PREC_AWAIT
	return 100


func _source(min_precedence: int) -> String:
	var text := _source_unwrapped()
	return "(%s)" % text if precedence() < min_precedence else text


func _source_unwrapped() -> String:
	match kind:
		Kind.LITERAL:
			return quote(value) if value is String else _literal_text(value)
		Kind.IDENTIFIER:
			return name
		Kind.UNARY:
			return ("not " if op == "not" else op) + operands[0]._source(precedence())
		Kind.AWAIT:
			return "await " + operands[0]._source(precedence())
		Kind.BINARY:
			var own := precedence()
			return "%s %s %s" % [operands[0]._source(own), op, operands[1]._source(own + 1)]
		Kind.TERNARY:
			var own := precedence()
			return "%s if %s else %s" % [operands[0]._source(own + 1), operands[1]._source(own + 1), operands[2]._source(own)]
		Kind.CALL:
			return "%s(%s)" % [operands[0]._source(100), ", ".join(_arg_sources())]
		Kind.ANNOTATION:
			var texts := _arg_sources()
			return "@%s" % name if texts.is_empty() else "@%s(%s)" % [name, ", ".join(texts)]
		Kind.ATTRIBUTE:
			return "%s.%s" % [operands[0]._source(100), name]
		Kind.INDEX:
			return "%s[%s]" % [operands[0]._source(100), operands[1]._source(0)]
		Kind.ARRAY:
			var items := PackedStringArray()
			for item in operands:
				items.append(item._source(0))
			return "[%s]" % ", ".join(items)
		Kind.DICTIONARY:
			var entries := PackedStringArray()
			for i in range(0, operands.size(), 2):
				entries.append("%s: %s" % [operands[i]._source(0), operands[i + 1]._source(0)])
			return "{%s}" % ", ".join(entries)
	return ""


func _arg_sources() -> PackedStringArray:
	var texts := PackedStringArray()
	for arg in args:
		texts.append(arg._source(0))
	for key in named_args:
		texts.append("%s = %s" % [key, named_args[key]._source(0)])
	return texts


func _arg_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for arg in args:
		texts.append(arg.to_sexpr())
	for key in named_args:
		texts.append("%s=%s" % [key, named_args[key].to_sexpr()])
	return texts


static func _literal_text(literal: Variant) -> String:
	if literal is String:
		return "\"%s\"" % literal.c_escape()
	if literal == null:
		return "null"
	if literal is float:
		var text := str(literal)
		return text if "." in text or "e" in text or "inf" in text or "nan" in text else text + ".0"
	return str(literal)

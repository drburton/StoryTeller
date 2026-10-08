class_name TaleWriter
extends RefCounted
## Builds the text of single TaleScript statements, without indentation.
## The visual editor uses these to rewrite one line after a card changes.


static func narration(text: String) -> String:
	return TaleExpr.quote(text)


static func dialogue(speaker: String, mood: String, text: String) -> String:
	return "%s%s: %s" % [speaker, " (%s)" % mood if not mood.is_empty() else "", TaleExpr.quote(text)]


## A call such as [code]backdrop("library", time = 1.5)[/code]. Arguments
## are TaleScript source; [param named] is a list of [name, source] pairs.
static func call_line(callee: String, args: PackedStringArray, named: Array = [], awaited := false) -> String:
	var parts := PackedStringArray(args)
	for pair in named:
		parts.append("%s = %s" % [pair[0], pair[1]])
	return "%s%s(%s)" % ["await " if awaited else "", callee, ", ".join(parts)]


static func jump(target: String) -> String:
	return "jump " + target


static func assign(target: String, op: String, value: String) -> String:
	return "%s %s %s" % [target, op, value]


static func choose(args: Array = []) -> String:
	if args.is_empty():
		return "choose:"
	var parts := PackedStringArray()
	for pair in args:
		parts.append("%s = %s" % [pair[0], pair[1]])
	return "choose(%s):" % ", ".join(parts)


static func option(text: String, condition := "") -> String:
	return "%s%s:" % [TaleExpr.quote(text), " if " + condition if not condition.strip_edges().is_empty() else ""]


static func condition_header(keyword: String, condition := "") -> String:
	return "else:" if keyword == "else" else "%s %s:" % [keyword, condition]


static func comment(text: String) -> String:
	return "# " + text


## Annotations written before a statement, as source, with a trailing space.
static func annotations_prefix(annotations: Array[TaleExpr]) -> String:
	var parts := PackedStringArray()
	for annotation in annotations:
		parts.append(annotation.to_source())
	return " ".join(parts) + " " if not parts.is_empty() else ""


## The end-of-line comment of [param node], or "".
static func comment_suffix(node: TaleNode) -> String:
	return " # " + node.comment.strip_edges() if node != null and node.kind != TaleNode.Kind.COMMENT and not node.comment.is_empty() else ""

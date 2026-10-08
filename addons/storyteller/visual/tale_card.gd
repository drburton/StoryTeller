class_name TaleCard
extends RefCounted
## One card in the visual editor: a view of one statement (or an if/elif/else
## chain) with its fields pulled out for editing. Anything the editor has no
## card for becomes a SCRIPT card that shows the raw text, so nothing is
## hidden or lost.

enum Kind { NARRATION, DIALOGUE, ACTION, CALL, JUMP, SET, CHOICE, CONDITION, COMMENT, SCRIPT }

var kind: Kind
## The statement. For CONDITION, the "if".
var node: TaleNode
## For CONDITION: the if, elif, and else nodes. For CHOICE: the options
## (and timeout). Each lane is [code]{"node": TaleNode, "cards": Array[TaleCard]}[/code].
var lanes: Array[Dictionary] = []
## Every node this card covers (the if/elif/else chain shares one card).
var nodes: Array[TaleNode] = []


## Cards for the statements of a block (a beat, an option, an if branch).
## [param beats] and [param tales] tell beat calls apart from actions.
static func build(parent: TaleNode, beats: PackedStringArray = [], tales: PackedStringArray = []) -> Array[TaleCard]:
	var cards: Array[TaleCard] = []
	var children := TaleEdit.content_children(parent)
	var i := 0
	while i < children.size():
		var child := children[i]
		var card := TaleCard.new()
		card.node = child
		card.nodes.append(child)
		card.kind = _kind_of(child, beats, tales)
		if card.kind == Kind.CONDITION:
			card.lanes.append({"node": child, "cards": build(child, beats, tales)})
			while i + 1 < children.size() and children[i + 1].kind in [TaleNode.Kind.ELIF, TaleNode.Kind.ELSE]:
				i += 1
				card.nodes.append(children[i])
				card.lanes.append({"node": children[i], "cards": build(children[i], beats, tales)})
				if children[i].kind == TaleNode.Kind.ELSE:
					break
		elif card.kind == Kind.CHOICE:
			for option in child.body:
				if option.kind == TaleNode.Kind.OPTION or option.kind == TaleNode.Kind.TIMEOUT:
					card.lanes.append({"node": option, "cards": build(option, beats, tales)})
		cards.append(card)
		i += 1
	return cards


## The text of a NARRATION or DIALOGUE card, or of a CHOICE lane.
static func text_of(node: TaleNode) -> String:
	return str(node.expr.value) if node.expr != null and node.expr.kind == TaleExpr.Kind.LITERAL else ""


## For ACTION and CALL cards: [code]{"callee", "args", "named", "awaited"}[/code]
## with argument values as TaleScript source.
static func call_parts(node: TaleNode) -> Dictionary:
	var expr := node.expr
	var awaited := false
	if expr.kind == TaleExpr.Kind.AWAIT:
		awaited = true
		expr = expr.operands[0]
	var args := PackedStringArray()
	for arg in expr.args:
		args.append(arg.to_source())
	var named := []
	for key in expr.named_args:
		named.append([key, expr.named_args[key].to_source()])
	return {"callee": expr.operands[0].to_source(), "args": args, "named": named, "awaited": awaited}


static func _kind_of(node: TaleNode, beats: PackedStringArray, tales: PackedStringArray) -> Kind:
	if _has_inline_body(node):
		return Kind.SCRIPT
	match node.kind:
		TaleNode.Kind.NARRATION:
			return Kind.NARRATION
		TaleNode.Kind.DIALOGUE:
			return Kind.DIALOGUE
		TaleNode.Kind.JUMP:
			return Kind.JUMP
		TaleNode.Kind.ASSIGN:
			return Kind.SET
		TaleNode.Kind.CHOOSE:
			return Kind.CHOICE
		TaleNode.Kind.IF:
			return Kind.CONDITION
		TaleNode.Kind.COMMENT:
			return Kind.COMMENT
		TaleNode.Kind.EXPRESSION:
			var expr := node.expr
			if expr.kind == TaleExpr.Kind.AWAIT:
				expr = expr.operands[0]
			if expr.kind != TaleExpr.Kind.CALL:
				return Kind.SCRIPT
			var callee := expr.operands[0]
			if callee.kind == TaleExpr.Kind.IDENTIFIER and callee.name in beats and expr.args.is_empty():
				return Kind.CALL
			if callee.kind == TaleExpr.Kind.ATTRIBUTE and callee.operands[0].kind == TaleExpr.Kind.IDENTIFIER \
					and callee.operands[0].name in tales and expr.args.is_empty():
				return Kind.CALL
			return Kind.ACTION
	return Kind.SCRIPT


static func _has_inline_body(node: TaleNode) -> bool:
	for child in node.body:
		if child.inline or _has_inline_body(child):
			return true
	return false

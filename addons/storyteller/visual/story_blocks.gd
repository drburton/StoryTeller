class_name StoryBlocks
extends RefCounted
## The blocks of Visual Novel StoryTeller Studio (docs/studio-design.md §5):
## what each block is called, its color group, and the TaleScript it stands
## for. [method describe] turns a card into a block, and [method line_for]
## writes a block back as one statement, so blocks edit the same .tale text
## as cards do (decision 0012). Anything a block can't show becomes a "code"
## block holding the raw text, so nothing is lost.
## [codeblock]
## var block := StoryBlocks.describe(card, source)
## # {"type": "show", "fields": {"character": "theo", "face": "happy", "position": "LEFT"}, ...}
## block["fields"]["position"] = "RIGHT"
## source = TaleEdit.set_statement(source, card.node, StoryBlocks.line_for(block))
## [/codeblock]

## Color groups of the palette, in palette order.
const GROUPS := {
	"talk": {"title": "Talk", "color": Color("4c97ff")},
	"act": {"title": "Act", "color": Color("9966ff")},
	"scene": {"title": "Scene", "color": Color("59c059")},
	"choose": {"title": "Choose", "color": Color("ff8c1a")},
	"numbers": {"title": "Numbers", "color": Color("ff6680")},
	"code": {"title": "Code", "color": Color("8a8f99")},
}

## Every block type: its group, its words with fields in braces, its fields'
## starting values, and its shape ("stack", "wrap" for blocks with arms,
## "cap" for blocks nothing can follow).
const TYPES := {
	"say": {"group": "talk", "words": "{character} {face} says {text}", "fields": {"character": "", "face": "", "text": "Hello!"}},
	"narrate": {"group": "talk", "words": "Narrator says {text}", "fields": {"text": "Once upon a time..."}},
	"ask_name": {"group": "talk", "words": "Ask the player {prompt} and keep it in {word}", "fields": {"prompt": "What is your name?", "word": "player_name"}},
	"show": {"group": "act", "words": "Show {character} {face} at {position}", "fields": {"character": "", "face": "", "position": "CENTER"}},
	"face": {"group": "act", "words": "Change the face of {character} to {face}", "fields": {"character": "", "face": ""}},
	"move": {"group": "act", "words": "Move {character} to {position}", "fields": {"character": "", "position": "RIGHT"}},
	"hide": {"group": "act", "words": "Hide {character}", "fields": {"character": ""}},
	"hide_all": {"group": "act", "words": "Hide everyone", "fields": {}},
	"animate": {"group": "act", "words": "{character} {motion}", "fields": {"character": "", "motion": "hop"}},
	"background": {"group": "scene", "words": "Background {picture}", "fields": {"picture": ""}},
	"big_picture": {"group": "scene", "words": "Big picture {picture}", "fields": {"picture": ""}},
	"hide_big_picture": {"group": "scene", "words": "Hide the big picture", "fields": {}},
	"music": {"group": "scene", "words": "Play music {track}", "fields": {"track": ""}},
	"stop_music": {"group": "scene", "words": "Stop the music", "fields": {}},
	"sound": {"group": "scene", "words": "Play sound {sound}", "fields": {"sound": ""}},
	"wait": {"group": "scene", "words": "Wait {seconds} seconds", "fields": {"seconds": "1.0"}},
	"weather": {"group": "scene", "words": "Weather {weather}", "fields": {"weather": "rain"}},
	"shake_screen": {"group": "scene", "words": "Shake the screen", "fields": {}},
	"choice": {"group": "choose", "words": "Choice", "fields": {}, "shape": "wrap"},
	"go_to": {"group": "choose", "words": "Go to scene {scene}", "fields": {"scene": ""}, "shape": "cap"},
	"the_end": {"group": "choose", "words": "The end", "fields": {}, "shape": "cap"},
	"set": {"group": "numbers", "words": "Set {number} to {value}", "fields": {"number": "", "value": "0"}},
	"add": {"group": "numbers", "words": "Add {value} to {number}", "fields": {"number": "", "value": "1"}},
	"take": {"group": "numbers", "words": "Take {value} from {number}", "fields": {"number": "", "value": "1"}},
	"if": {"group": "numbers", "words": "If", "fields": {}, "shape": "wrap"},
	"note": {"group": "code", "words": "Note: {text}", "fields": {"text": ""}},
	"code": {"group": "code", "words": "{code}", "fields": {"code": ""}},
}

## Stage positions by constant, with the words students see.
const POSITIONS := {"LEFT": "left", "CENTER": "middle", "RIGHT": "right"}
## Comparisons in an If arm, by operator.
const COMPARISONS := {">=": "is at least", ">": "is more than", "==": "is", "!=": "is not", "<=": "is at most", "<": "is less than"}
## Character motions, by method.
const MOTIONS := {"hop": "hops", "shake": "shakes", "nod": "nods"}
const WEATHERS := {"rain": "rain", "snow": "snow", "none": "clear"}

## Calls with one picture or sound name, by block type.
const _NAME_CALLS := {"backdrop": ["background", "picture"], "cg": ["big_picture", "picture"], "music": ["music", "track"],
	"sound": ["sound", "sound"], "weather": ["weather", "weather"]}
## Calls with no arguments, by block type.
const _BARE_CALLS := {"hide_cg": "hide_big_picture", "stop_music": "stop_music", "shake": "shake_screen", "exit_all": "hide_all"}


## A new block of [param type] with its starting values.
static func new_block(type: String) -> Dictionary:
	var info: Dictionary = TYPES[type]
	var block := {"type": type, "fields": info["fields"].duplicate(), "extra": {}}
	if type == "choice":
		block["arms"] = [_option_arm("Option one"), _option_arm("Option two")]
	elif type == "if":
		block["arms"] = [{"keyword": "if", "test": "compare", "fields": {"number": "", "comparison": ">=", "value": "1"}}]
	return block


## The group, color, and shape of [param type].
static func group_of(type: String) -> String:
	return TYPES[type]["group"]


static func color_of(type: String) -> Color:
	return GROUPS[group_of(type)]["color"]


static func shape_of(type: String) -> String:
	return TYPES[type].get("shape", "stack")


## The block for [param card], read from [param source]. Returns
## [code]{"type", "fields", "extra"}[/code], plus [code]"arms"[/code] for
## Choice and If: one dictionary per option or branch, each with the card's
## lane cards under [code]"cards"[/code].
static func describe(card: TaleCard, source: String) -> Dictionary:
	var block := _describe_node(card)
	if block.is_empty():
		block = {"type": "code", "fields": {"code": TaleEdit.group_text(source, card.nodes)}, "extra": {}}
	# Rewriting the line would lose a trailing comment or annotations.
	if block["type"] not in ["code", "note"] and (card.node.annotations.size() > 0 or not card.node.comment.is_empty()):
		block = {"type": "code", "fields": {"code": TaleEdit.group_text(source, card.nodes)}, "extra": {}}
	return block


## The statement for [param block], without indentation. For Choice and If
## this is the first line only; use [method arm_line] for the arms, and
## [method new_text] for a whole new block.
static func line_for(block: Dictionary) -> String:
	var f: Dictionary = block["fields"]
	var extra: Dictionary = block.get("extra", {})
	match block["type"]:
		"say":
			return TaleWriter.dialogue(f["character"], f["face"], f["text"])
		"narrate":
			return TaleWriter.narration(f["text"])
		"ask_name":
			return "%s = await %s" % [f["word"], _call("ask_text", [TaleExpr.quote(f["prompt"])], extra)]
		"show":
			var args := PackedStringArray([TaleExpr.quote(f["face"])]) if not str(f["face"]).is_empty() else PackedStringArray()
			var named := [["at", f["position"]]]
			named.append_array(extra.get("named", []))
			return TaleWriter.call_line("%s.enter" % f["character"], args, named, extra.get("awaited", false))
		"face":
			return "%s.mood = %s" % [f["character"], TaleExpr.quote(f["face"])]
		"move":
			return _call("%s.move_to" % f["character"], [f["position"]], extra)
		"hide":
			return _call("%s.exit" % f["character"], [], extra)
		"animate":
			return _call("%s.%s" % [f["character"], f["motion"]], [], extra)
		"background", "big_picture", "music", "sound", "weather":
			for callee in _NAME_CALLS:
				if _NAME_CALLS[callee][0] == block["type"]:
					return _call(callee, [TaleExpr.quote(f[_NAME_CALLS[callee][1]])], extra)
		"hide_big_picture", "stop_music", "shake_screen", "hide_all":
			for callee in _BARE_CALLS:
				if _BARE_CALLS[callee] == block["type"]:
					return _call(callee, [], extra)
		"wait":
			return _call("wait", [f["seconds"]], extra)
		"choice":
			return TaleWriter.choose(extra.get("args", []))
		"go_to":
			return TaleWriter.jump(f["scene"])
		"the_end":
			return "return"
		"set":
			return TaleWriter.assign(f["number"], "=", f["value"])
		"add":
			return TaleWriter.assign(f["number"], "+=", f["value"])
		"take":
			return TaleWriter.assign(f["number"], "-=", f["value"])
		"if":
			return arm_line(block["arms"][0])
		"note":
			return TaleWriter.comment(f["text"])
		"code":
			return f["code"]
	return ""


## The header line of one arm of a Choice or If: an option such as
## [code]"Look outside":[/code], or [code]if score >= 2:[/code],
## [code]elif ...:[/code], or [code]else:[/code].
static func arm_line(arm: Dictionary) -> String:
	if arm.has("text"):
		return arm.get("prefix", "") + TaleWriter.option(arm["text"], arm.get("condition", ""))
	return TaleWriter.condition_header(arm["keyword"], condition_text(arm))


## The condition an If arm tests, as TaleScript.
static func condition_text(arm: Dictionary) -> String:
	var f: Dictionary = arm.get("fields", {})
	match arm.get("test", ""):
		"compare":
			return "%s %s %s" % [f["number"], f["comparison"], f["value"]]
		"visited":
			return "visited(%s)" % TaleExpr.quote(f["scene"])
		"code":
			return f["condition"]
	return ""


## Full text of a new block, ready for [method TaleEdit.insert_after] and
## friends: wrapped blocks get their arms, each holding [code]pass[/code].
static func new_text(block: Dictionary, indent_unit := "\t") -> String:
	if not block.has("arms"):
		return line_for(block)
	var lines := PackedStringArray()
	if block["type"] == "choice":
		lines.append(line_for(block))
		for arm in block["arms"]:
			lines.append(indent_unit + arm_line(arm))
			lines.append(indent_unit.repeat(2) + "pass")
	else:
		for arm in block["arms"]:
			lines.append(arm_line(arm))
			lines.append(indent_unit + "pass")
	return "\n".join(lines)


## The words shown on [param block], with each field replaced by
## [param show_field] called as (field_name, value) -> String.
static func words_of(block: Dictionary, show_field: Callable) -> String:
	var words: String = TYPES[block["type"]]["words"]
	for field in block["fields"]:
		words = words.replace("{%s}" % field, show_field.call(field, block["fields"][field]))
	return words


static func _describe_node(card: TaleCard) -> Dictionary:
	var node := card.node
	match card.kind:
		TaleCard.Kind.DIALOGUE:
			if _is_plain_text(node.expr):
				return _block("say", {"character": node.name, "face": node.mood, "text": str(node.expr.value)})
		TaleCard.Kind.NARRATION:
			if _is_plain_text(node.expr):
				return _block("narrate", {"text": str(node.expr.value)})
		TaleCard.Kind.JUMP:
			return _block("go_to", {"scene": node.jump_target})
		TaleCard.Kind.COMMENT:
			return _block("note", {"text": node.comment.strip_edges()})
		TaleCard.Kind.SET:
			return _describe_assign(node)
		TaleCard.Kind.ACTION:
			return _describe_call(node.expr)
		TaleCard.Kind.CHOICE:
			return _describe_choice(card)
		TaleCard.Kind.CONDITION:
			return _describe_condition(card)
		TaleCard.Kind.SCRIPT:
			if node.kind == TaleNode.Kind.RETURN and node.expr == null:
				return _block("the_end", {})
	return {}


static func _describe_assign(node: TaleNode) -> Dictionary:
	var target := node.target.to_source()
	var value := node.expr
	if node.op == "=" and value.kind == TaleExpr.Kind.AWAIT and value.operands[0].kind == TaleExpr.Kind.CALL \
			and value.operands[0].get_call_name() == "ask_text" and node.target.kind == TaleExpr.Kind.IDENTIFIER:
		var call := value.operands[0]
		if call.args.size() == 1 and _is_plain_text(call.args[0]):
			var block := _block("ask_name", {"prompt": str(call.args[0].value), "word": target})
			block["extra"] = _extra_named(call, [])
			return block
		return {}
	if node.target.kind == TaleExpr.Kind.ATTRIBUTE and node.target.name == "mood" and node.op == "=" \
			and node.target.operands[0].kind == TaleExpr.Kind.IDENTIFIER and _is_plain_text(value):
		return _block("face", {"character": node.target.operands[0].name, "face": str(value.value)})
	match node.op:
		"=":
			return _block("set", {"number": target, "value": value.to_source()})
		"+=":
			return _block("add", {"number": target, "value": value.to_source()})
		"-=":
			return _block("take", {"number": target, "value": value.to_source()})
	return {}


static func _describe_call(expr: TaleExpr) -> Dictionary:
	var awaited := false
	if expr.kind == TaleExpr.Kind.AWAIT:
		awaited = true
		expr = expr.operands[0]
	var callee := expr.operands[0]
	var block := {}
	if callee.kind == TaleExpr.Kind.IDENTIFIER:
		var name := callee.name
		if name in _NAME_CALLS and expr.args.size() == 1 and _is_plain_text(expr.args[0]):
			block = _block(_NAME_CALLS[name][0], {_NAME_CALLS[name][1]: str(expr.args[0].value)})
		elif name in _BARE_CALLS and expr.args.is_empty():
			block = _block(_BARE_CALLS[name], {})
		elif name == "wait" and expr.args.size() == 1 and expr.args[0].kind == TaleExpr.Kind.LITERAL:
			block = _block("wait", {"seconds": expr.args[0].to_source()})
	elif callee.kind == TaleExpr.Kind.ATTRIBUTE and callee.operands[0].kind == TaleExpr.Kind.IDENTIFIER:
		var character := callee.operands[0].name
		match callee.name:
			"enter":
				if expr.args.size() <= 1 and (expr.args.is_empty() or _is_plain_text(expr.args[0])) and expr.named_args.has("at"):
					block = _block("show", {"character": character, "face": str(expr.args[0].value) if expr.args.size() == 1 else "",
						"position": expr.named_args["at"].to_source()})
					block["extra"] = _extra_named(expr, ["at"])
					block["extra"]["awaited"] = awaited
					return block
			"move_to":
				if expr.args.size() == 1:
					block = _block("move", {"character": character, "position": expr.args[0].to_source()})
			"exit":
				if expr.args.is_empty():
					block = _block("hide", {"character": character})
			"hop", "shake", "nod":
				if expr.args.is_empty():
					block = _block("animate", {"character": character, "motion": callee.name})
	if block.is_empty():
		return {}
	block["extra"] = _extra_named(expr, [])
	block["extra"]["awaited"] = awaited
	return block


static func _describe_choice(card: TaleCard) -> Dictionary:
	var block := _block("choice", {})
	var args := []
	if card.node.expr != null:
		if not card.node.expr.args.is_empty():
			return {}
		for key in card.node.expr.named_args:
			args.append([key, card.node.expr.named_args[key].to_source()])
	block["extra"]["args"] = args
	block["arms"] = []
	for lane in card.lanes:
		var option: TaleNode = lane["node"]
		if option.kind != TaleNode.Kind.OPTION or not _is_plain_text(option.expr) or not option.comment.is_empty():
			return {}
		var arm := _option_arm(str(option.expr.value))
		arm["condition"] = option.condition.to_source() if option.condition != null else ""
		arm["prefix"] = TaleWriter.annotations_prefix(option.annotations)
		arm["node"] = option
		arm["cards"] = lane["cards"]
		block["arms"].append(arm)
	return block


static func _describe_condition(card: TaleCard) -> Dictionary:
	var block := _block("if", {})
	block["arms"] = []
	for lane in card.lanes:
		var branch: TaleNode = lane["node"]
		if not branch.comment.is_empty():
			return {}
		var keyword := "if" if branch.kind == TaleNode.Kind.IF else "elif" if branch.kind == TaleNode.Kind.ELIF else "else"
		var arm := {"keyword": keyword, "node": branch, "cards": lane["cards"]}
		if keyword != "else":
			arm.merge(_describe_test(branch.expr))
		block["arms"].append(arm)
	return block


static func _describe_test(condition: TaleExpr) -> Dictionary:
	if condition.kind == TaleExpr.Kind.BINARY and condition.op in COMPARISONS \
			and condition.operands[0].kind in [TaleExpr.Kind.IDENTIFIER, TaleExpr.Kind.ATTRIBUTE] \
			and condition.operands[1].kind == TaleExpr.Kind.LITERAL:
		return {"test": "compare", "fields": {"number": condition.operands[0].to_source(), "comparison": condition.op, "value": condition.operands[1].to_source()}}
	if condition.kind == TaleExpr.Kind.CALL and condition.get_call_name() == "visited" and condition.args.size() == 1 \
			and _is_plain_text(condition.args[0]):
		return {"test": "visited", "fields": {"scene": str(condition.args[0].value)}}
	return {"test": "code", "fields": {"condition": condition.to_source()}}


static func _block(type: String, fields: Dictionary) -> Dictionary:
	return {"type": type, "fields": fields, "extra": {}}


static func _option_arm(text: String) -> Dictionary:
	return {"text": text, "condition": "", "prefix": ""}


static func _is_plain_text(expr: TaleExpr) -> bool:
	return expr != null and expr.kind == TaleExpr.Kind.LITERAL and expr.value is String


## Arguments a block has no field for, kept so rewriting the line loses
## nothing: named arguments other than [param shown].
static func _extra_named(expr: TaleExpr, shown: Array) -> Dictionary:
	var named := []
	for key in expr.named_args:
		if key not in shown:
			named.append([key, expr.named_args[key].to_source()])
	return {"named": named}


static func _call(callee: String, args: Array, extra: Dictionary) -> String:
	return TaleWriter.call_line(callee, PackedStringArray(args), extra.get("named", []), extra.get("awaited", false))

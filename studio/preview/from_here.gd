class_name StudioFromHere
extends RefCounted
## What a story does on the way to a chosen block and after it, as
## TaleScript, for the stage preview and Play from here
## (docs/studio-design.md §7).
##
## The setup keeps only what changes the stage and the numbers on the way:
## backgrounds, big pictures, characters entering, leaving, moving, and
## changing faces, weather, numbers, and Ifs that hold those. Lines,
## choices, sounds, and waits on the way are left out. When the block is
## inside a Choice, only its own option counts; inside an If, its own arm.
## Both start from the beginning of the block's scene.

const PREVIEW_BEAT := "studio_preview"
const FROM_HERE_BEAT := "studio_from_here"
## Calls that change what is on stage.
const STAGE_CALLS := ["backdrop", "cg", "hide_cg", "exit_all", "weather", "filter", "prop", "hide_prop", "clear_props"]
## A character's methods that change the stage.
const CAST_CALLS := ["enter", "exit", "move_to"]
## Calls that start or stop music, kept for Play from here.
const AUDIO_CALLS := ["music", "stop_music", "ambience", "stop_ambience"]


## [param source] compiled as the tale [param tale_name], or null when its
## text has a mistake. Problems the checker finds don't stop it: the Studio
## shows them as hints on the blocks (docs/studio-design.md §2).
static func compile_story(source: String, tale_name: String, context: TaleCheckContext) -> Tale:
	var doc := TaleParser.parse(source)
	if doc.has_errors():
		return null
	var checker := TaleChecker.new()
	checker.run(doc, context if context != null else TaleCheckContext.new())
	return TaleCompiler.compile(doc, tale_name, checker.call_kinds)


## [param source] with a beat that sets the stage as it is at
## [param target] and then shows the target itself, when it is a line, a
## choice, or a change to the stage. Play it from [constant PREVIEW_BEAT].
static func preview_source(source: String, doc: TaleDocument, target: TaleNode) -> String:
	var body := PackedStringArray([setup_text(source, doc, target)])
	body.append(_shown_text(source, doc, target))
	return _with_beat(source, doc, PREVIEW_BEAT, "\n".join(body))


## [param source] with a beat that sets the stage, the numbers, and the
## music as they are at [param target], and then goes on from it the way
## the story would. Play it from [constant FROM_HERE_BEAT].
static func from_here_source(source: String, doc: TaleDocument, target: TaleNode) -> String:
	var body := PackedStringArray([setup_text(source, doc, target, true), continuation_text(source, doc, target)])
	return _with_beat(source, doc, FROM_HERE_BEAT, "\n".join(body))


## The statements on the way to [param target] that set the stage, as text
## without indentation. With [param with_audio], music too.
static func setup_text(source: String, doc: TaleDocument, target: TaleNode, with_audio := false) -> String:
	var lines := PackedStringArray()
	for level in _levels(doc, target):
		var container: TaleNode = level[0]
		if container.kind == TaleNode.Kind.CHOOSE:
			continue
		var siblings := TaleEdit.content_children(container)
		var stop := _chain_start(siblings, siblings.find(level[1]))
		var i := 0
		while i < stop:
			var group := _group_at(siblings, i)
			var text := _kept(source, doc, group, with_audio)
			if not text.is_empty():
				lines.append(text)
			i += group.size()
	return "\n".join(lines)


## [param target] and everything the story does after it in its scene: the
## rest of its list, then what follows the Choice or If it is inside, as
## text without indentation.
static func continuation_text(source: String, doc: TaleDocument, target: TaleNode) -> String:
	var parts := PackedStringArray()
	var levels := _levels(doc, target)
	levels.reverse()
	for n in levels.size():
		var container: TaleNode = levels[n][0]
		if container.kind == TaleNode.Kind.CHOOSE:
			continue
		var siblings := TaleEdit.content_children(container)
		var from := siblings.find(levels[n][1])
		if n > 0:
			# Past the If chain or Choice the inner levels came from.
			from += 1
			while from < siblings.size() and siblings[from].kind in [TaleNode.Kind.ELIF, TaleNode.Kind.ELSE]:
				from += 1
		for i in range(from, siblings.size()):
			parts.append(TaleEdit.group_text(source, [siblings[i]]))
	return "\n".join(parts)


## The blocks around [param target], outermost first, as
## [code][container, child][/code] pairs from its beat down to the target.
static func _levels(doc: TaleDocument, target: TaleNode) -> Array:
	var levels := []
	var node := target
	while true:
		var parent := TaleEdit.find_parent(doc, node)
		if parent == null:
			break
		levels.push_front([parent, node])
		if parent.kind == TaleNode.Kind.BEAT:
			break
		node = parent
	return levels


## Where the If chain holding [code]siblings[index][/code] starts, when it
## is an elif or else arm; otherwise [param index].
static func _chain_start(siblings: Array[TaleNode], index: int) -> int:
	var start := index
	while start > 0 and siblings[start].kind in [TaleNode.Kind.ELIF, TaleNode.Kind.ELSE] \
			and siblings[start - 1].kind in [TaleNode.Kind.IF, TaleNode.Kind.ELIF]:
		start -= 1
	return start


## The statement at [param i], with its elif and else arms when it is an If.
static func _group_at(siblings: Array[TaleNode], i: int) -> Array[TaleNode]:
	var group: Array[TaleNode] = [siblings[i]]
	if siblings[i].kind == TaleNode.Kind.IF:
		var j := i + 1
		while j < siblings.size() and siblings[j].kind in [TaleNode.Kind.ELIF, TaleNode.Kind.ELSE]:
			group.append(siblings[j])
			if siblings[j].kind == TaleNode.Kind.ELSE:
				break
			j += 1
	return group


## The part of [param group] that sets the stage or the numbers, or "".
static func _kept(source: String, doc: TaleDocument, group: Array[TaleNode], with_audio: bool) -> String:
	var node := group[0]
	match node.kind:
		TaleNode.Kind.VAR:
			return TaleEdit.group_text(source, [node])
		TaleNode.Kind.ASSIGN:
			# An answer the player types would open a question in the preview.
			if node.expr != null and node.expr.kind == TaleExpr.Kind.AWAIT:
				return ""
			return TaleEdit.group_text(source, [node])
		TaleNode.Kind.EXPRESSION:
			return TaleEdit.group_text(source, [node]) if _changes_stage(node.expr, with_audio) else ""
		TaleNode.Kind.IF:
			return _kept_chain(source, doc, group, with_audio)
	return ""


## An If chain with only the statements that set the stage in its arms, or
## "" when none of them do.
static func _kept_chain(source: String, doc: TaleDocument, chain: Array[TaleNode], with_audio: bool) -> String:
	var unit := TaleEdit.indent_unit(doc)
	var out := PackedStringArray()
	var kept_any := false
	for branch in chain:
		if branch.line_end != branch.line_start or branch.body.any(func(child: TaleNode) -> bool: return child.inline):
			return ""
		out.append(doc.lines[branch.line_start - 1].strip_edges())
		var body := PackedStringArray()
		var children := TaleEdit.content_children(branch)
		var i := 0
		while i < children.size():
			var group := _group_at(children, i)
			var text := _kept(source, doc, group, with_audio)
			if not text.is_empty():
				body.append(text)
			i += group.size()
		kept_any = kept_any or not body.is_empty()
		if body.is_empty():
			body.append("pass")
		for line in "\n".join(body).split("\n"):
			out.append(unit + line if not line.is_empty() else "")
	return "\n".join(out) if kept_any else ""


static func _changes_stage(expr: TaleExpr, with_audio: bool) -> bool:
	if expr == null:
		return false
	if expr.kind == TaleExpr.Kind.AWAIT:
		expr = expr.operands[0]
	if expr.kind != TaleExpr.Kind.CALL:
		return false
	var callee := expr.operands[0]
	if callee.kind == TaleExpr.Kind.IDENTIFIER:
		return callee.name in STAGE_CALLS or (with_audio and callee.name in AUDIO_CALLS)
	return callee.kind == TaleExpr.Kind.ATTRIBUTE and callee.name in CAST_CALLS \
		and callee.operands[0].kind == TaleExpr.Kind.IDENTIFIER


## The target itself, when the preview can show it: a line, a choice, or a
## change to the stage or the numbers.
static func _shown_text(source: String, doc: TaleDocument, target: TaleNode) -> String:
	match target.kind:
		TaleNode.Kind.DIALOGUE, TaleNode.Kind.NARRATION, TaleNode.Kind.CHOOSE:
			return TaleEdit.group_text(source, [target])
		TaleNode.Kind.ASSIGN, TaleNode.Kind.EXPRESSION:
			return _kept(source, doc, [target], false)
	return ""


## [param source] with a new beat [param beat_name] holding [param body].
static func _with_beat(source: String, doc: TaleDocument, beat_name: String, body: String) -> String:
	var unit := TaleEdit.indent_unit(doc)
	var lines := PackedStringArray()
	for line in body.split("\n"):
		if not line.strip_edges().is_empty():
			lines.append(unit + line)
	if lines.is_empty():
		lines.append(unit + "pass")
	var text := source if source.ends_with("\n") else source + "\n"
	return text + "\nbeat %s:\n%s\n" % [beat_name, "\n".join(lines)]

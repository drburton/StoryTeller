extends "res://tests/framework/story_test.gd"
## Tests for StudioFromHere (studio/preview/): the setup on the way to a
## block and the rest of the story after it, for the stage preview and Play
## from here.

const SOURCE := """var score := 0

beat start:
	backdrop("yard")
	maya.enter("happy", at = LEFT)
	maya: "Hi"
	sound("ding")
	music("theme")
	choose:
		"Look in the box":
			score += 1
			maya.mood = "sad"
			maya: "Empty."
		"Look outside":
			jump yard
	if score >= 1:
		sam.enter(at = RIGHT)
		sam: "Found it!"
	else:
		"Nothing here."
	"The end of the start."

beat yard:
	"The yard is quiet."
"""


func _find(doc: TaleDocument, text: String) -> TaleNode:
	var pending: Array = doc.statements.duplicate()
	while not pending.is_empty():
		var node: TaleNode = pending.pop_front()
		if doc.lines[node.line_start - 1].strip_edges() == text:
			return node
		pending.append_array(node.body)
	return null


func test_the_setup_inside_a_choice_keeps_its_own_option() -> void:
	var doc := TaleParser.parse(SOURCE)
	var target := _find(doc, "maya: \"Empty.\"")
	assert_eq(StudioFromHere.setup_text(SOURCE, doc, target),
		"backdrop(\"yard\")\nmaya.enter(\"happy\", at = LEFT)\nscore += 1\nmaya.mood = \"sad\"")
	assert_eq(StudioFromHere.setup_text(SOURCE, doc, target, true),
		"backdrop(\"yard\")\nmaya.enter(\"happy\", at = LEFT)\nmusic(\"theme\")\nscore += 1\nmaya.mood = \"sad\"", "music for Play from here")


func test_ifs_on_the_way_keep_what_sets_the_stage() -> void:
	var doc := TaleParser.parse(SOURCE)
	var target := _find(doc, "\"The end of the start.\"")
	assert_eq(StudioFromHere.setup_text(SOURCE, doc, target),
		"backdrop(\"yard\")\nmaya.enter(\"happy\", at = LEFT)\nif score >= 1:\n\tsam.enter(at = RIGHT)\nelse:\n\tpass")


func test_inside_an_if_only_its_own_arm_counts() -> void:
	var doc := TaleParser.parse(SOURCE)
	assert_eq(StudioFromHere.setup_text(SOURCE, doc, _find(doc, "\"Nothing here.\"")),
		"backdrop(\"yard\")\nmaya.enter(\"happy\", at = LEFT)")
	assert_eq(StudioFromHere.setup_text(SOURCE, doc, _find(doc, "sam: \"Found it!\"")),
		"backdrop(\"yard\")\nmaya.enter(\"happy\", at = LEFT)\nsam.enter(at = RIGHT)")


func test_the_story_goes_on_after_the_block() -> void:
	var doc := TaleParser.parse(SOURCE)
	assert_eq(StudioFromHere.continuation_text(SOURCE, doc, _find(doc, "maya: \"Empty.\"")),
		"maya: \"Empty.\"\nif score >= 1:\n\tsam.enter(at = RIGHT)\n\tsam: \"Found it!\"\nelse:\n\t\"Nothing here.\"\n\"The end of the start.\"")
	assert_eq(StudioFromHere.continuation_text(SOURCE, doc, _find(doc, "\"Nothing here.\"")),
		"\"Nothing here.\"\n\"The end of the start.\"")
	var beat := doc.find_beat("start")
	assert_eq(StudioFromHere.continuation_text(SOURCE, doc, _find(doc, "backdrop(\"yard\")")),
		TaleEdit.group_text(SOURCE, TaleEdit.content_children(beat)), "from the first block it is the whole scene")


func test_the_new_beats_make_valid_tales() -> void:
	var doc := TaleParser.parse(SOURCE)
	for line in ["maya: \"Hi\"", "maya: \"Empty.\"", "jump yard", "sam: \"Found it!\"", "\"The end of the start.\"", "choose:", "\"The yard is quiet.\""]:
		var target := _find(doc, line)
		for text in [StudioFromHere.preview_source(SOURCE, doc, target), StudioFromHere.from_here_source(SOURCE, doc, target)]:
			var made := TaleParser.parse(text)
			assert_false(made.has_errors(), "%s: %s" % [line, text])
	var preview := TaleParser.parse(StudioFromHere.preview_source(SOURCE, doc, _find(doc, "maya: \"Empty.\"")))
	var beat := preview.find_beat(StudioFromHere.PREVIEW_BEAT)
	assert_eq(TaleEdit.group_text(StudioFromHere.preview_source(SOURCE, doc, _find(doc, "maya: \"Empty.\"")), TaleEdit.content_children(beat)),
		"backdrop(\"yard\")\nmaya.enter(\"happy\", at = LEFT)\nscore += 1\nmaya.mood = \"sad\"\nmaya: \"Empty.\"", "the preview ends on the block")
	var jump := TaleParser.parse(StudioFromHere.preview_source(SOURCE, doc, _find(doc, "jump yard")))
	var jump_beat := jump.find_beat(StudioFromHere.PREVIEW_BEAT)
	assert_false(TaleEdit.content_children(jump_beat).any(func(node: TaleNode) -> bool: return node.kind == TaleNode.Kind.JUMP), "a preview never leaves the scene")

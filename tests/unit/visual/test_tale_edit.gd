extends "res://tests/framework/story_test.gd"
## Tests for TaleEdit, TaleWriter, and TaleCard: visual edits change only the
## lines they touch and keep the tale valid.

const SOURCE := """## A tale for edit tests.
var trust := 0

beat start:
	# The room.
	"Sunlight."  # first line
	mira (smile): "Hi."
	backdrop("library", time = 1.5)
	choose:
		"Wave":
			trust += 1
		@once "Leave" if trust > 0:
			jump other
	if trust > 1:
		"Close friends."
	elif trust > 0:
		"Friends."
	else:
		pass
	other()

beat other:
	pass
"""


func _doc(source: String) -> TaleDocument:
	var doc := TaleParser.parse(source)
	assert_false(doc.has_errors(), "%s" % [doc.diagnostics])
	return doc


func _beat(doc: TaleDocument, beat_name := "start") -> TaleNode:
	return doc.find_beat(beat_name)


## Lines that differ, as [before, after] for the changed middle part.
func _diff(a: String, b: String) -> Array:
	var x := a.split("\n")
	var y := b.split("\n")
	var start := 0
	while start < x.size() and start < y.size() and x[start] == y[start]:
		start += 1
	var end_x := x.size() - 1
	var end_y := y.size() - 1
	while end_x >= start and end_y >= start and x[end_x] == y[end_y]:
		end_x -= 1
		end_y -= 1
	return [Array(x.slice(start, end_x + 1)), Array(y.slice(start, end_y + 1))]


func test_span_leaves_out_trailing_blank_lines() -> void:
	var doc := _doc(SOURCE)
	assert_eq(TaleEdit.span(_beat(doc)), Vector2i(4, 20))
	var choose := TaleEdit.content_children(_beat(doc))[4]
	assert_eq(TaleEdit.span(choose), Vector2i(9, 13))


func test_set_statement_changes_one_line_and_keeps_comments() -> void:
	var doc := _doc(SOURCE)
	var dialogue := TaleEdit.content_children(_beat(doc))[2]
	var text := TaleWriter.dialogue("mira", "sad", "Hello \"you\".")
	var edited := TaleEdit.set_statement(SOURCE, dialogue, text)
	assert_eq(_diff(SOURCE, edited), [["\tmira (smile): \"Hi.\""], ["\tmira (sad): \"Hello \\\"you\\\".\""]])
	_doc(edited)


func test_narration_keeps_its_end_of_line_comment() -> void:
	var doc := _doc(SOURCE)
	var narration := TaleEdit.content_children(_beat(doc))[1]
	var text := TaleWriter.annotations_prefix(narration.annotations) + TaleWriter.narration("Moonlight.") + TaleWriter.comment_suffix(narration)
	assert_eq(_diff(SOURCE, TaleEdit.set_statement(SOURCE, narration, text)), [["\t\"Sunlight.\"  # first line"], ["\t\"Moonlight.\" # first line"]])


func test_insert_before_after_and_append() -> void:
	var doc := _doc(SOURCE)
	var children := TaleEdit.content_children(_beat(doc))
	var after := TaleEdit.insert_after(SOURCE, children[4], "\"After the choice.\"")
	assert_eq(_diff(SOURCE, after), [[], ["\t\"After the choice.\""]])
	assert_eq(after.split("\n")[13], "\t\"After the choice.\"", "after the whole choose block")
	var before := TaleEdit.insert_before(SOURCE, children[2], "wait(1)")
	assert_eq(before.split("\n")[6], "\twait(1)", "just above the dialogue line")
	var appended := TaleEdit.append_to(SOURCE, doc, _beat(doc, "other"), "\"The end.\"")
	assert_eq(_diff(SOURCE, appended), [["\tpass"], ["\t\"The end.\""]], "a lone pass is replaced")
	_doc(appended)


func test_delete_removes_block_and_keeps_tale_valid() -> void:
	var doc := _doc(SOURCE)
	var choose := TaleEdit.content_children(_beat(doc))[4]
	var removed := TaleEdit.delete(SOURCE, doc, choose)
	assert_eq(_diff(SOURCE, removed)[1], [])
	assert_eq(_diff(SOURCE, removed)[0].size(), 5)
	_doc(removed)
	var wave_body := TaleEdit.content_children(choose.body[0])[0]
	var emptied := TaleEdit.delete(SOURCE, doc, wave_body)
	assert_eq(_diff(SOURCE, emptied), [["\t\t\ttrust += 1"], ["\t\t\tpass"]], "an empty block gets pass")
	_doc(emptied)


func test_move_within_and_between_blocks() -> void:
	var doc := _doc(SOURCE)
	var beat := _beat(doc)
	var children := TaleEdit.content_children(beat)
	# Move the backdrop call to the top of the beat.
	var moved := TaleEdit.move(SOURCE, doc, children[3], beat, 0)
	var lines := moved.split("\n")
	assert_eq(lines[4], "\tbackdrop(\"library\", time = 1.5)")
	assert_eq(lines[5], "\t# The room.")
	_doc(moved)
	# Move the dialogue line into the "Wave" option, after trust += 1.
	var doc2 := _doc(SOURCE)
	var wave: TaleNode = TaleEdit.content_children(_beat(doc2))[4].body[0]
	var into := TaleEdit.move(SOURCE, doc2, TaleEdit.content_children(_beat(doc2))[2], wave, 1)
	var into_doc := _doc(into)
	var new_wave: TaleNode = TaleEdit.content_children(_beat(into_doc))[3].body[0]
	assert_eq(TaleEdit.block_text(into, TaleEdit.content_children(new_wave)[1]), "mira (smile): \"Hi.\"")
	assert_eq(TaleEdit.content_children(new_wave)[1].indent, "\t\t\t")
	# Move the last statement of a block out: the block gets pass.
	var doc3 := _doc(SOURCE)
	var leave: TaleNode = TaleEdit.content_children(_beat(doc3))[4].body[1]
	var out := TaleEdit.move(SOURCE, doc3, TaleEdit.content_children(leave)[0], _beat(doc3, "other"), 0)
	assert_true(out.contains("\t\t@once \"Leave\" if trust > 0:\n\t\t\tpass\n"))
	assert_true(out.ends_with("beat other:\n\tjump other\n"))
	_doc(out)


func test_replace_block_reindents_script_text() -> void:
	var doc := _doc(SOURCE)
	var condition := TaleEdit.content_children(_beat(doc))[5]
	assert_eq(TaleEdit.block_text(SOURCE, condition), "if trust > 1:\n\t\"Close friends.\"")
	var edited := TaleEdit.replace_block(SOURCE, condition, "if trust > 2:\n\t\"Best friends.\"")
	assert_eq(_diff(SOURCE, edited), [["\tif trust > 1:", "\t\t\"Close friends.\""], ["\tif trust > 2:", "\t\t\"Best friends.\""]])


func test_add_beat_and_crlf_and_spaces() -> void:
	var doc := _doc(SOURCE)
	assert_true(TaleEdit.add_beat(SOURCE, doc, "finale").ends_with("\tpass\n\nbeat finale:\n\tpass\n"))
	var crlf := SOURCE.replace("\n", "\r\n")
	var crlf_doc := _doc(crlf)
	var edited := TaleEdit.set_statement(crlf, TaleEdit.content_children(_beat(crlf_doc))[1], "\"Rain.\"")
	assert_eq(edited, crlf.replace("\t\"Sunlight.\"  # first line", "\t\"Rain.\""))
	var spaces := "beat a:\n    \"One.\"\n"
	var spaces_doc := _doc(spaces)
	assert_eq(TaleEdit.indent_unit(spaces_doc), "    ")
	assert_eq(TaleEdit.add_beat(spaces, spaces_doc, "b"), "beat a:\n    \"One.\"\n\nbeat b:\n    pass\n")


func test_cards_for_a_beat() -> void:
	var doc := _doc(SOURCE)
	var cards := TaleCard.build(_beat(doc), PackedStringArray(["start", "other"]))
	var kinds := cards.map(func(card: TaleCard) -> String: return TaleCard.Kind.keys()[card.kind])
	assert_eq(kinds, ["COMMENT", "NARRATION", "DIALOGUE", "ACTION", "CHOICE", "CONDITION", "CALL"])
	assert_eq(cards[4].lanes.size(), 2)
	assert_eq(TaleCard.text_of(cards[4].lanes[1]["node"]), "Leave")
	assert_eq(cards[4].lanes[1]["cards"][0].kind, TaleCard.Kind.JUMP)
	assert_eq(cards[5].lanes.map(func(lane: Dictionary) -> int: return lane["node"].kind), [TaleNode.Kind.IF, TaleNode.Kind.ELIF, TaleNode.Kind.ELSE])
	assert_eq(cards[5].lanes[2]["cards"], [], "a lone pass shows no card")
	assert_eq(TaleCard.call_parts(cards[3].node), {"callee": "backdrop", "args": PackedStringArray(["\"library\""]), "named": [["time", "1.5"]], "awaited": false})


func test_unsupported_statements_become_script_cards() -> void:
	var source := "beat a:\n\tfor i in 3:\n\t\t\"Again.\"\n\tif done: jump a\n\tvar x := 1\n\tawait mira.exit()\n"
	var cards := TaleCard.build(_doc(source).statements[0])
	var kinds := cards.map(func(card: TaleCard) -> String: return TaleCard.Kind.keys()[card.kind])
	assert_eq(kinds, ["SCRIPT", "SCRIPT", "SCRIPT", "ACTION"])
	assert_true(TaleCard.call_parts(cards[3].node)["awaited"])


func test_writer_builds_statements_that_parse() -> void:
	var lines := [
		TaleWriter.call_line("ada.enter", PackedStringArray(["\"smile\""]), [["at", "CENTER"]], true),
		TaleWriter.jump("chapter_1.start"),
		TaleWriter.assign("trust", "+=", "2"),
		TaleWriter.choose([["timeout", "5.0"]]),
		TaleWriter.comment("note"),
	]
	assert_eq(lines[0], "await ada.enter(\"smile\", at = CENTER)")
	assert_eq(lines[3], "choose(timeout = 5.0):")
	var source := "beat a:\n\t%s\n\t%s\n\t%s\n\t%s\n\t\t%s\n\t\t\tpass\n\t\t%s\n\t\t\tpass\n\t%s\n" % [lines[0], lines[2], lines[4], lines[3], TaleWriter.option("Yes", "trust > 1"), TaleWriter.option("No"), lines[1]]
	_doc(source)
	assert_eq(TaleWriter.condition_header("elif", "x > 1"), "elif x > 1:")
	assert_eq(TaleWriter.condition_header("else"), "else:")

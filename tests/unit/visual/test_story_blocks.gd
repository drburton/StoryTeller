extends "res://tests/framework/story_test.gd"
## Tests for StoryBlocks, the Studio's blocks: every statement a block shows
## is written back exactly, and new blocks make valid tales.

const TALES := [
	"res://examples/wheres_biscuit/tales/wheres_biscuit.tale",
	"res://demo/tales/welcome.tale",
	"res://demo/tales/prologue.tale",
	"res://demo/tales/chapter_1.tale",
	"res://demo/tales/chapter_2.tale",
]
const SAMPLE_FIELDS := {
	"character": "theo", "face": "happy", "text": "Hi!", "prompt": "Your name?", "word": "player_name",
	"position": "LEFT", "motion": "nod", "picture": "yard", "track": "theme", "sound": "ding", "seconds": "2.0",
	"weather": "snow", "scene": "start", "number": "score", "value": "3", "code": "for i in 2:\n\tpass",
}


## Cards of every beat in [param doc], including cards inside choices and ifs.
func _all_cards(doc: TaleDocument) -> Array[TaleCard]:
	var cards: Array[TaleCard] = []
	var pending: Array[TaleCard] = []
	for statement in doc.statements:
		if statement.kind == TaleNode.Kind.BEAT:
			pending.append_array(TaleCard.build(statement))
	while not pending.is_empty():
		var card: TaleCard = pending.pop_front()
		cards.append(card)
		for lane in card.lanes:
			pending.append_array(lane["cards"])
	return cards


## The first line of [param node]'s dump: the statement without its body.
func _header(node: TaleNode) -> String:
	return RegEx.create_from_string(" \\[\\d+\\]$").sub(node.dump().split("\n")[0], "")


## The parsed statement for one line of TaleScript inside a beat.
func _parse_line(line: String) -> TaleNode:
	var doc := TaleParser.parse("beat t:\n\t%s\n\t\tpass\n" % line if line.ends_with(":") else "beat t:\n\t%s\n" % line)
	return TaleEdit.content_children(doc.statements[0])[0]


func test_every_statement_a_block_shows_is_written_back_exactly() -> void:
	for path in TALES:
		var source := FileAccess.get_file_as_string(path)
		var doc := TaleParser.parse(source)
		for card in _all_cards(doc):
			var block := StoryBlocks.describe(card, source)
			if block["type"] == "code":
				continue
			if block["type"] == "choice" or block["type"] == "if":
				for arm in block["arms"]:
					var arm_line := StoryBlocks.arm_line(arm)
					var wrapped := ("choose:\n\t\t" + arm_line) if block["type"] == "choice" else arm_line
					var opening := "" if block["type"] == "choice" or arm["keyword"] == "if" else "if x:\n\t\tpass\n\t"
					var parsed := TaleParser.parse("beat t:\n\t%s\n\t\t\tpass\n" % wrapped if block["type"] == "choice" else "beat t:\n\t%s%s\n\t\tpass\n" % [opening, arm_line])
					var node: TaleNode = TaleEdit.content_children(parsed.statements[0]).back()
					if block["type"] == "choice":
						node = node.body[0]
					assert_eq(_header(node), _header(arm["node"]), "%s:%d arm" % [path.get_file(), arm["node"].line_start])
				if block["type"] == "if":
					continue
			assert_eq(_header(_parse_line(StoryBlocks.line_for(block))), _header(card.node), "%s:%d %s" % [path.get_file(), card.node.line_start, block["type"]])


func test_the_example_story_needs_no_code_blocks() -> void:
	var source := FileAccess.get_file_as_string(TALES[0])
	var types := {}
	for card in _all_cards(TaleParser.parse(source)):
		var block := StoryBlocks.describe(card, source)
		assert_ne(block["type"], "code", "line %d: %s" % [card.node.line_start, block["fields"].get("code", "")])
		types[block["type"]] = true
	for type in ["say", "narrate", "show", "hide", "hide_all", "animate", "background", "choice", "go_to", "add", "if"]:
		assert_true(types.has(type), type)


func test_changing_a_field_rewrites_only_that_line() -> void:
	var source := FileAccess.get_file_as_string(TALES[0])
	var doc := TaleParser.parse(source)
	for card in _all_cards(doc):
		var block := StoryBlocks.describe(card, source)
		if block["type"] == "show" and block["fields"]["character"] == "theo":
			block["fields"]["position"] = "RIGHT"
			block["fields"]["face"] = "sad"
			var changed := TaleEdit.set_statement(source, card.node, StoryBlocks.line_for(block))
			var before := source.split("\n")
			var after := changed.split("\n")
			assert_eq(after.size(), before.size())
			var differing := []
			for i in before.size():
				if before[i] != after[i]:
					differing.append(after[i])
			assert_eq(differing, ["\ttheo.enter(\"sad\", at = RIGHT)"])
			return
	fail("no Show block for Theo")


func test_extra_arguments_and_waits_are_kept() -> void:
	var card := TaleCard.build(TaleParser.parse("beat t:\n\tawait ada.enter(\"smile\", at = LEFT, time = 0.6)\n\tbackdrop(\"park\", transition = \"none\")\n").statements[0])
	var show := StoryBlocks.describe(card[0], "")
	assert_eq(show["type"], "show")
	assert_eq(StoryBlocks.line_for(show), "await ada.enter(\"smile\", at = LEFT, time = 0.6)")
	assert_eq(StoryBlocks.line_for(StoryBlocks.describe(card[1], "")), "backdrop(\"park\", transition = \"none\")")


func test_lines_a_block_cannot_show_become_code_blocks() -> void:
	var source := "beat t:\n\tbackdrop(Color.BLACK)\n\tfor i in 3:\n\t\tpass\n\ttheo: \"Hi\" # greeting\n\t@id(\"x\") \"Hello\"\n\tmatch score:\n\t\t1:\n\t\t\tpass\n"
	var cards := TaleCard.build(TaleParser.parse(source).statements[0])
	var types := cards.map(func(card: TaleCard) -> String: return StoryBlocks.describe(card, source)["type"])
	assert_eq(types, ["code", "code", "code", "code", "code"])
	assert_eq(StoryBlocks.describe(cards[1], source)["fields"]["code"], "for i in 3:\n\tpass")


func test_every_new_block_makes_a_valid_tale_and_reads_back_as_itself() -> void:
	for type in StoryBlocks.TYPES:
		var block := StoryBlocks.new_block(type)
		for field in block["fields"]:
			block["fields"][field] = SAMPLE_FIELDS.get(field, block["fields"][field])
		if type == "if":
			block["arms"][0]["fields"] = {"number": "score", "comparison": ">=", "value": "2"}
			block["arms"].append({"keyword": "else"})
		if type == "note":
			block["fields"]["text"] = "Remember the ending"
		var text := StoryBlocks.new_text(block)
		var source := "var score := 0\nvar player_name := \"\"\n\nbeat start:\n" + "\n".join(Array(text.split("\n")).map(func(line: String) -> String: return "\t" + line)) + "\n\tpass\n"
		var doc := TaleParser.parse(source)
		for statement in doc.statements:
			assert_ne(statement.kind, TaleNode.Kind.ERROR, "%s: %s" % [type, source])
		var beat: TaleNode = doc.statements.back()
		var cards := TaleCard.build(beat)
		if cards.is_empty():
			fail("%s made no card: %s" % [type, source])
			continue
		var card := cards[0]
		var back := StoryBlocks.describe(card, source)
		assert_eq(back["type"], type, source)
		assert_eq(back["fields"], block["fields"], type)


func test_words_show_the_fields() -> void:
	var block := StoryBlocks.new_block("show")
	block["fields"] = {"character": "theo", "face": "happy", "position": "LEFT"}
	var words := StoryBlocks.words_of(block, func(field: String, value: String) -> String:
		return StoryBlocks.POSITIONS.get(value, value) if field == "position" else "[%s]" % value)
	assert_eq(words, "Show [theo] [happy] at left")
	assert_eq(StoryBlocks.color_of("say"), StoryBlocks.GROUPS["talk"]["color"])
	assert_eq(StoryBlocks.shape_of("go_to"), "cap")
	assert_eq(StoryBlocks.shape_of("choice"), "wrap")
	assert_eq(StoryBlocks.shape_of("say"), "stack")

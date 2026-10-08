extends "res://tests/framework/story_test.gd"
## Tests for TaleChecker.


func _context() -> TaleCheckContext:
	var context := TaleCheckContext.new()
	context.tale_name = "prologue"
	context.add_action("backdrop", ["name", "transition", "time"], 1)
	context.add_action("music", ["track", "volume"], 1)
	context.add_action("wait", ["seconds"], 1)
	context.add_action_unchecked("emit")
	context.add_cast("mira", ["smile", "curious", "soft", "smirk"])
	context.add_cast("jonas")
	context.add_exposed("player_name")
	context.add_exposed("inventory")
	context.add_tale("chapter_1", ["start", "flashback"], ["met_jonas"])
	return context


## Checks [param source] and returns diagnostics as "line: message" strings,
## with "warning: " in front of warnings.
func _check(source: String) -> PackedStringArray:
	var doc := TaleParser.parse(source)
	var texts := PackedStringArray()
	for diagnostic in doc.diagnostics:
		texts.append("%d: parse: %s" % [diagnostic.line, diagnostic.message])
	for diagnostic in TaleChecker.check(doc, _context()):
		var prefix := "" if diagnostic.is_error() else "warning: "
		texts.append("%d: %s%s" % [diagnostic.line, prefix, diagnostic.message])
	return texts


func _beat(body: String) -> PackedStringArray:
	return _check("beat main:\n" + body)


func test_plan_sample_is_clean() -> void:
	var source := FileAccess.get_file_as_string("res://tests/fixtures/talescript/prologue.tale")
	assert_eq(_check(source), PackedStringArray())


func test_unknown_names() -> void:
	assert_eq(_beat("\tx = 1\n"), PackedStringArray(["2: Unknown variable 'x'. Declare it first with 'var x'."]))
	assert_eq(_beat("\tif missing > 1:\n\t\tpass\n"), PackedStringArray(["2: Unknown name 'missing'."]))
	assert_eq(_beat("\tfly()\n"), PackedStringArray(["2: Unknown action or beat 'fly'."]))


func test_locals_are_block_scoped_and_ordered() -> void:
	assert_eq(_beat("\tvar a := 1\n\tif a > 0:\n\t\tvar b := a\n\ta = b\n"),
		PackedStringArray(["5: Unknown name 'b'."]))
	assert_eq(_beat("\tx = 1\n\tvar x := 0\n"),
		PackedStringArray(["2: Unknown variable 'x'. Declare it first with 'var x'."]))
	assert_eq(_beat("\tfor item in [1, 2]:\n\t\temit(\"i\", item)\n"), PackedStringArray())


func test_story_variables_and_constants() -> void:
	var source := "const LIMIT := 3\nvar gold := 0\nbeat main:\n\tgold += LIMIT\n\tLIMIT = 4\n"
	assert_eq(_check(source), PackedStringArray(["5: Can't assign to the constant 'LIMIT'."]))


func test_duplicate_declarations() -> void:
	assert_eq(_check("var a := 1\nbeat a:\n\tpass\n"), PackedStringArray(["2: 'a' is already declared on line 1."]))
	assert_eq(_beat("\tvar t := 1\n\tvar t := 2\n"), PackedStringArray(["3: 't' is already declared in this block."]))


func test_shadowing_is_a_warning() -> void:
	assert_eq(_check("var gold := 0\nbeat main:\n\tvar gold := 1\n"),
		PackedStringArray(["3: warning: 'gold' hides the story variable with the same name."]))


func test_speakers() -> void:
	assert_eq(_beat("\tmira (smile): \"Hi\"\n\tjonas (any): \"Yo\"\n"), PackedStringArray())
	assert_eq(_beat("\tmira (angry): \"Hi\"\n"), PackedStringArray(["2: warning: Cast member 'mira' has no mood 'angry'."]))
	assert_eq(_check("const NARRATOR := \"Old Man\"\nbeat main:\n\tNARRATOR: \"Long ago...\"\n"), PackedStringArray())
	assert_eq(_beat("\tghost: \"Boo\"\n"), PackedStringArray(
		["2: Unknown speaker 'ghost'. Use a cast member id or a const holding the speaker's name."]))


func test_text_interpolation() -> void:
	assert_eq(_beat("\t\"Hi {player_name}, {{literal}}.\"\n"), PackedStringArray())
	assert_eq(_beat("\t\"You have {coins} coins.\"\n"), PackedStringArray(["2: Unknown name 'coins'."]))
	assert_eq(_beat("\t\"Broken {brace.\"\n"), PackedStringArray(["2: Unclosed '{' in text. Write '{{' for a literal brace."]))


func test_jumps() -> void:
	var source := "beat main:\n\tjump end\nbeat end:\n\tjump chapter_1.start\n"
	assert_eq(_check(source), PackedStringArray())
	assert_eq(_beat("\tjump nowhere\n"), PackedStringArray(["2: Unknown beat 'nowhere'."]))
	assert_eq(_beat("\tjump chapter_1.middle\n"), PackedStringArray(["2: Tale 'chapter_1' has no beat 'middle'."]))
	assert_eq(_beat("\tjump chapter_9.start\n"), PackedStringArray(["2: Unknown tale 'chapter_9'."]))
	assert_eq(_beat("\tjump prologue.main\n"), PackedStringArray(), "a tale can name itself")


func test_beat_calls() -> void:
	var source := "beat main:\n\thelper()\n\tchapter_1.flashback()\nbeat helper:\n\treturn\n"
	assert_eq(_check(source), PackedStringArray())
	assert_eq(_check("beat main:\n\thelper(1)\nbeat helper:\n\tpass\n"), PackedStringArray(["2: Beats don't take arguments."]))
	assert_eq(_beat("\tchapter_1.ending()\n"), PackedStringArray(["2: Tale 'chapter_1' has no beat 'ending'."]))
	assert_eq(_beat("\tif chapter_1.met_jonas:\n\t\tpass\n"), PackedStringArray())


func test_call_kinds_are_recorded() -> void:
	var doc := TaleParser.parse("beat main:\n\thelper()\n\twait(1)\n\tmira.enter()\n\tchapter_1.start()\n\tmax(1, 2)\nbeat helper:\n\tpass\n")
	var checker := TaleChecker.new()
	checker.run(doc, _context())
	var kinds := []
	for statement in doc.statements[0].body:
		kinds.append(checker.call_kinds.get(statement.expr, "?"))
	assert_eq(kinds, ["beat", "action", "method", "tale_beat", "function"])


func test_action_arguments() -> void:
	assert_eq(_beat("\tbackdrop(\"a\", time = 1)\n"), PackedStringArray())
	assert_eq(_beat("\tbackdrop(time = 1)\n"), PackedStringArray(["2: 'backdrop' needs the argument 'name'."]))
	assert_eq(_beat("\tbackdrop(\"a\", speed = 2)\n"), PackedStringArray(["2: 'backdrop' has no argument named 'speed'."]))
	assert_eq(_beat("\tbackdrop(\"a\", name = \"b\")\n"), PackedStringArray(["2: Argument 'name' is already given by position."]))
	assert_eq(_beat("\tmusic(1, 2, 3)\n"), PackedStringArray(["2: 'music' takes at most 2 arguments, but 3 were given."]))
	assert_eq(_beat("\temit(1, 2, 3, x = 4)\n"), PackedStringArray(), "unchecked actions accept anything")


func test_type_constants() -> void:
	assert_eq(_beat("\tvar c := Color.RED\n\tvar v := Vector2.ZERO\n"), PackedStringArray())


func test_misused_names() -> void:
	assert_eq(_check("beat main:\n\tvar x = helper\nbeat helper:\n\tpass\n"),
		PackedStringArray(["2: 'helper' is a beat. Call it with helper() or use 'jump helper'."]))
	assert_eq(_beat("\tmira = 3\n"), PackedStringArray(["2: Can't assign to 'mira', because it is a cast member."]))
	assert_eq(_beat("\tvar n := 1\n\tn()\n"), PackedStringArray(["3: 'n' is a variable and can't be called."]))


func test_if_chain_order() -> void:
	assert_eq(_beat("\tif true:\n\t\tpass\n\t# note\n\telse:\n\t\tpass\n"), PackedStringArray())
	assert_eq(_beat("\tpass\n\telse:\n\t\tpass\n"), PackedStringArray(["3: 'else' must follow an 'if' or 'elif' block."]))
	assert_eq(_beat("\tpass\n\telif true:\n\t\tpass\n"), PackedStringArray(["3: 'elif' must follow an 'if' or 'elif' block."]))


func test_loop_control_and_return() -> void:
	assert_eq(_beat("\tbreak\n"), PackedStringArray(["2: 'break' can only be used inside a loop."]))
	assert_eq(_beat("\twhile true:\n\t\tif true:\n\t\t\tcontinue\n\t\tbreak\n"), PackedStringArray())
	assert_eq(_beat("\treturn 1\n"), PackedStringArray(["2: Beats don't return values. Use 'return' on its own."]))


func test_unreachable_code_is_a_warning() -> void:
	assert_eq(_check("beat main:\n\tjump other\n\t\"never\"\n\t\"also never\"\nbeat other:\n\tpass\n"),
		PackedStringArray(["3: warning: This line can never run, because the line before it always leaves the block."]))


func test_useless_expression_is_a_warning() -> void:
	assert_eq(_beat("\tvar a := 1\n\ta + 1\n"), PackedStringArray(["3: warning: This expression has no effect."]))


func test_choose_rules() -> void:
	assert_eq(_beat("\tchoose(timeout = 3):\n\t\t\"A\": pass\n\t\ttimeout: pass\n"), PackedStringArray())
	assert_eq(_beat("\tchoose:\n\t\ttimeout: pass\n"), PackedStringArray([
		"2: A 'choose' block needs at least one option.",
		"3: warning: 'timeout:' only runs when the choose has a timeout, e.g. choose(timeout = 5.0):",
	]))
	assert_eq(_beat("\tchoose(\"list\"):\n\t\t\"A\": pass\n"),
		PackedStringArray(["2: choose only takes named arguments, e.g. choose(style = \"list\")."]))


func test_match_rules() -> void:
	assert_eq(_check("const GOOD := 1\nbeat main:\n\tmatch 2:\n\t\tGOOD, 2: pass\n\t\t_ when true: pass\n\t\t_: pass\n"), PackedStringArray())
	assert_eq(_beat("\tmatch 1:\n\t\t_: pass\n\t\t2: pass\n"),
		PackedStringArray(["4: warning: This branch can never match, because an earlier '_' branch matches everything."]))
	assert_eq(_beat("\tmatch 1:\n\t\t1 + 1: pass\n"), PackedStringArray(["3: Match patterns must be literals, constants, or '_'."]))


func test_annotations() -> void:
	var good := "@title(\"Prologue\")\n@global var seen := false\nbeat main:\n\t@id(\"a1\") mira: \"Hi\"\n\t@voice(\"v1\")\n\t\"Narration\"\n\tchoose:\n\t\t@once \"A\": pass\n\t@no_rewind\n\twait(1)\n"
	assert_eq(_check(good), PackedStringArray())
	assert_eq(_beat("\t@once \"Narration\"\n"), PackedStringArray(["2: @once only applies to choice options."]))
	assert_eq(_check("@title(\"A\")\n@title(\"B\")\n"), PackedStringArray(["2: A tale can only have one @title."]))
	assert_eq(_beat("\t@id(\"x\") \"one\"\n\t@id(\"x\") \"two\"\n"), PackedStringArray(["3: Line id 'x' is already used on line 2."]))
	assert_eq(_beat("\t@id(3) \"one\"\n"), PackedStringArray(["2: @id needs one text argument, e.g. @id(\"...\")."]))
	assert_eq(_beat("\tchoose:\n\t\t@id(\"opt\") \"A\": pass\n"), PackedStringArray(), "options can pin their id")
	assert_eq(_beat("\t@id(\"w\")\n\twait(1)\n"), PackedStringArray(["2: @id only applies to dialogue, narration, and choice options."]))
	assert_eq(_beat("\tchoose:\n\t\t@voice(\"v\") \"A\": pass\n"), PackedStringArray(["3: @voice only applies to dialogue and narration lines."]))
	assert_eq(_beat("\t@sparkle \"one\"\n"), PackedStringArray(["2: Unknown annotation '@sparkle'."]))
	assert_eq(_beat("\tpass\n\t@no_rewind\n"), PackedStringArray(["3: @no_rewind is not followed by a line it can apply to."]))
	assert_eq(_check("@global const A := 1\n"), PackedStringArray(["1: @global only applies to a 'var' at the top level of the tale."]))


func test_parse_errors_are_not_repeated() -> void:
	var doc := TaleParser.parse("beat main:\n\tif x y:\n\t\tpass\n")
	assert_eq(doc.diagnostics.size(), 1)
	assert_eq(TaleChecker.check(doc, _context()).size(), 0)

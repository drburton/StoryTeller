extends "res://tests/framework/story_test.gd"
## Tests for TaleCompiler and the Tale resource.


func _build(source: String) -> Tale:
	var result := TaleCompiler.build(source, "test")
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail("unexpected error: %s" % diagnostic)
	return result["tale"]


## Instruction ops of [param tale] as "index:op" or "index:op>target".
func _ops(tale: Tale) -> PackedStringArray:
	var ops := PackedStringArray()
	for i in tale.instructions.size():
		var instruction := tale.instructions[i]
		var text := "%d:%s" % [i, instruction["op"]]
		if instruction.has("target"):
			text += ">%d" % instruction["target"]
		ops.append(text)
	return ops


func test_beats_and_variables() -> void:
	var tale := _build("@title(\"T\")\n@global var seen := false\nconst A := 1\nbeat one:\n\t\"x\"\nbeat two:\n\tpass\n")
	assert_eq(tale.title, "T")
	assert_eq(tale.tale_name, "test")
	assert_eq(tale.get_beat_start("one"), 0)
	assert_eq(tale.get_beat_start("two"), 2)
	assert_eq(tale.get_beat_start("three"), -1)
	assert_eq(tale.variables.size(), 2)
	assert_true(tale.variables[0]["global"])
	assert_true(tale.variables[1]["const"])
	assert_eq(tale.variables[1]["value"], ["lit", 1])


func test_say_instruction() -> void:
	var tale := _build("const N := \"Ned\"\nvar g := 2\nbeat b:\n\tN: \"Gold: {g * 2}!\"\n")
	var say := tale.instructions[0]
	assert_eq(say["op"], "say")
	assert_eq(say["speaker"], "N")
	assert_eq(say["text"], ["Gold: ", ["bin", "*", ["name", "g"], ["lit", 2]], "!"])
	assert_eq(say["line"], 4)


func test_if_chain_jumps() -> void:
	var tale := _build("var x := 1\nbeat b:\n\tif x == 1:\n\t\t\"one\"\n\telif x == 2:\n\t\t\"two\"\n\telse:\n\t\t\"other\"\n\t\"after\"\n")
	assert_eq(_ops(tale), PackedStringArray([
		"0:branch_false>3", "1:say", "2:goto>7",
		"3:branch_false>6", "4:say", "5:goto>7",
		"6:say", "7:say", "8:end",
	]))


func test_while_with_break_and_continue() -> void:
	var tale := _build("var x := 0\nbeat b:\n\twhile x < 5:\n\t\tx += 1\n\t\tif x == 2:\n\t\t\tcontinue\n\t\tif x == 4:\n\t\t\tbreak\n")
	assert_eq(_ops(tale), PackedStringArray([
		"0:branch_false>7", "1:set",
		"2:branch_false>4", "3:goto>0",
		"4:branch_false>6", "5:goto>7",
		"6:goto>0", "7:end",
	]))


func test_for_loop() -> void:
	var tale := _build("beat b:\n\tfor i in [1, 2]:\n\t\t\"{i}\"\n")
	assert_eq(_ops(tale), PackedStringArray(["0:iter_begin", "1:iter_next>4", "2:say", "3:goto>1", "4:end"]))
	assert_eq(tale.instructions[1]["var"], "i")
	assert_eq(tale.instructions[0]["slot"], tale.instructions[1]["slot"])


func test_match() -> void:
	var tale := _build("var x := 1\nbeat b:\n\tmatch x:\n\t\t1, 2: \"low\"\n\t\t_ when x > 9: \"high\"\n\t\"after\"\n")
	var instruction := tale.instructions[0]
	assert_eq(instruction["op"], "match")
	assert_eq(instruction["branches"][0]["patterns"], [["lit", 1], ["lit", 2]])
	assert_eq(instruction["branches"][1]["patterns"], [null])
	assert_eq(instruction["branches"][1]["guard"], ["bin", ">", ["name", "x"], ["lit", 9]])
	assert_eq(instruction["branches"][0]["target"], 1)
	assert_eq(instruction["branches"][1]["target"], 3)
	assert_eq(instruction["end"], 5)
	assert_eq(_ops(tale), PackedStringArray(["0:match", "1:say", "2:goto>5", "3:say", "4:goto>5", "5:say", "6:end"]))


func test_choose() -> void:
	var tale := _build("var k := false\nbeat b:\n\tchoose(timeout = 3.0):\n\t\t@once \"A\": jump b\n\t\t\"B\" if k:\n\t\t\tpass\n\t\ttimeout: \"slow\"\n")
	var instruction := tale.instructions[0]
	assert_eq(instruction["args"], {"timeout": ["lit", 3.0]})
	var options: Array = instruction["options"]
	assert_eq(options.size(), 2)
	assert_true(options[0]["once"])
	assert_eq(options[0]["target"], 1)
	assert_eq(options[1]["cond"], ["name", "k"])
	assert_eq(options[1]["target"], 3)
	assert_eq(instruction["timeout_target"], 4)
	assert_eq(instruction["end"], 6)
	assert_eq(_ops(tale), PackedStringArray(["0:choose", "1:jump", "2:goto>6", "3:goto>6", "4:say", "5:goto>6", "6:end"]))


func test_calls_jumps_and_assignments() -> void:
	var context := TaleCheckContext.new()
	context.add_action_unchecked("shake")
	context.add_tale("other", ["start"])
	var result := TaleCompiler.build("var n := 0\nbeat b:\n\thelp()\n\tother.start()\n\tshake(1, power = 2)\n\tn += 1\n\tjump other.start\n\treturn\nbeat help:\n\tpass\n", "test", context)
	var tale: Tale = result["tale"]
	var instructions := tale.instructions
	assert_eq(instructions[0], {"op": "call_beat", "tale": "", "beat": "help", "line": 3})
	assert_eq(instructions[1], {"op": "call_beat", "tale": "other", "beat": "start", "line": 4})
	assert_eq(instructions[2]["expr"], ["call", ["name", "shake"], [["lit", 1]], {"power": ["lit", 2]}])
	assert_eq(instructions[3], {"op": "set", "place": ["name", "n"], "assign": "+=", "value": ["lit", 1], "line": 6})
	assert_eq(instructions[4], {"op": "jump", "tale": "other", "beat": "start", "line": 7})
	assert_eq(instructions[5]["op"], "return")


func test_line_ids() -> void:
	var tale := _build("beat b:\n\t\"Same\"\n\t\"Same\"\n\t@id(\"pinned\") \"Other\"\n")
	var first: String = tale.instructions[0]["id"]
	assert_true(first.begins_with("b_"))
	assert_eq(tale.instructions[1]["id"], first + "_2", "repeated text gets a unique id")
	assert_eq(tale.instructions[2]["id"], "pinned")


func test_annotations_on_instructions() -> void:
	var tale := _build("beat b:\n\t@voice(\"v1\") \"Hi\"\n\t@no_rewind\n\t\"Point of no return\"\n")
	assert_eq(tale.instructions[0]["voice"], "v1")
	assert_true(tale.instructions[1].get("no_rewind", false))
	assert_false(tale.instructions[0].get("no_rewind", false))


func test_build_reports_errors_without_a_tale() -> void:
	var parse_error := TaleCompiler.build("beat b:\n\tif x y:\n\t\tpass\n", "test")
	assert_null(parse_error["tale"])
	var check_error := TaleCompiler.build("beat b:\n\tjump nowhere\n", "test")
	assert_null(check_error["tale"])
	assert_eq(check_error["diagnostics"][0].message, "Unknown beat 'nowhere'.")


func test_tale_survives_save_and_load() -> void:
	var tale := _build("var x := 1\nbeat b:\n\tif x > 0:\n\t\t\"Hi {x}\"\n")
	var path := "user://test_tale_roundtrip.res"
	assert_eq(ResourceSaver.save(tale, path), OK)
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Tale
	assert_not_null(loaded)
	assert_eq(loaded.instructions, tale.instructions)
	assert_eq(loaded.beats, tale.beats)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_imported_tale_loads_as_resource() -> void:
	var tale := load("res://tests/import/sample.tale") as Tale
	assert_not_null(tale, "the import plugin compiled sample.tale")
	if tale:
		assert_eq(tale.title, "Import Sample")
		assert_eq(tale.tale_name, "sample")
		assert_eq(tale.get_beat_start("start"), 0)

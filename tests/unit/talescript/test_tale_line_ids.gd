extends "res://tests/framework/story_test.gd"
## Tests for pinning line ids.

const SOURCE := "beat start:\n\t\"Hello.\"\n\t@id(\"kept\") \"Already pinned.\"\n\t@id(\"above\")\n\t\"Pinned above.\"\n\tmira: \"\"\"Two\n\tlines.\"\"\"\n\tchoose:\n\t\t@once \"Go\": pass\n\t\t\"Stay\":\n\t\t\tif true:\n\t\t\t\t\"Nested.\"\n\t\"Hello.\"\n"


func test_pinning_keeps_every_id() -> void:
	var before := TaleCompiler.compile(TaleParser.parse(SOURCE), "t")
	var result := TaleLineIds.pin(SOURCE, "t")
	assert_eq(result["error"], "")
	assert_eq(result["count"], 6, "two lines were pinned already")
	var after := TaleCompiler.compile(TaleParser.parse(result["text"]), "t")
	assert_eq(after.texts, before.texts, "every line keeps its id and text")
	var lines: PackedStringArray = result["text"].split("\n")
	assert_eq(lines[1], "\t@id(\"start_%s\") \"Hello.\"" % "Hello.".md5_text().substr(0, 6))
	assert_eq(lines[2], "\t@id(\"kept\") \"Already pinned.\"")
	assert_eq(lines[4], "\t\"Pinned above.\"")
	assert_true(lines[5].begins_with("\t@id(\"start_"))
	assert_true(lines[5].ends_with(" mira: \"\"\"Two"))
	assert_true(lines[8].contains(" @once \"Go\": pass"))
	assert_true(lines[11].begins_with("\t\t\t\t@id(\""))
	assert_true(lines[12].ends_with("_2\") \"Hello.\""), "a repeated line keeps its numbered id")
	assert_eq(TaleLineIds.pin(result["text"], "t")["count"], 0, "pinning twice changes nothing")


func test_pinned_tale_checks_cleanly() -> void:
	var pinned: String = TaleLineIds.pin(SOURCE.replace("mira", "Mira"), "t")["text"]
	var built := TaleCompiler.build("const Mira := \"Mira\"\n" + pinned, "t")
	for diagnostic in built["diagnostics"]:
		fail(str(diagnostic))


func test_syntax_errors_leave_the_tale_alone() -> void:
	var broken := "beat start:\n\t\"open\n"
	var result := TaleLineIds.pin(broken, "t")
	assert_eq(result["text"], broken)
	assert_eq(result["count"], 0)
	assert_eq(result["error"], "Fix the syntax errors in t first.")

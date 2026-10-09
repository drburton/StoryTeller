extends "res://tests/framework/story_test.gd"
## Tests for YarnConverter: Yarn Spinner scripts become tales that check
## cleanly and play.

const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const SAMPLE := "res://demo/yarn/lighthouse.yarn"

var director: TaleDirector
var presenter: ScriptedPresenter


func before_each() -> void:
	director = track(TaleDirector.new())
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(director)
	tree.root.add_child(presenter)
	director.presenter = presenter


## Converts [param source], checks the tale, and adds it to the director.
func _load(source: String, cast := PackedStringArray()) -> Dictionary:
	var result := YarnConverter.to_tale(source, "yarn_test", cast)
	var context := director.make_check_context("yarn_test")
	for id in cast:
		context.add_cast(id)
	var built := TaleCompiler.build(result["text"], "yarn_test", context)
	for diagnostic in built["diagnostics"]:
		fail("%s\n%s" % [diagnostic, result["text"]])
	if built["tale"] != null:
		director.add_tale(built["tale"])
	return result


func test_sample_converts_to_a_clean_tale_that_plays() -> void:
	var result := _load(FileAccess.get_file_as_string(SAMPLE))
	assert_eq(result["notes"], PackedStringArray(["Line 32: <<fade_out 1>> was not converted; it is kept as a comment."]))
	assert_eq(result["beats"], {"Start": "start", "Lamp": "lamp", "Shore": "shore"})
	presenter.picks = ["Ask about the key.", "Ask about the lamp."]
	await director.play("yarn_test")
	assert_eq(presenter.offered[1], ["Ask about the lamp.", "Leave."], "the key option is hidden once the player has the key")
	assert_eq(presenter.lines, [
		"The lighthouse door is open. Wind pulls at your coat.",
		"Keeper: You came up the long stairs for something. What is it?",
		"Keeper: Here. Don't lose it.",
		"The lighthouse door is open. Wind pulls at your coat.",
		"Keeper: You came up the long stairs for something. What is it?",
		"Keeper: It has not been lit in a year.",
		"You turn the key, and the lamp flares to life.",
		"Keeper: Thank you for climbing up.",
		"The waves keep their own time.",
	])
	assert_eq(presenter.line_data[0]["id"], "lh_start_1", "#line: tags become line ids")


func test_lines_and_speakers() -> void:
	var result := YarnConverter.to_tale("title: Talk\n---\nMira: Hi, {$name}! \\{not a value\\}\nOld Guide: Welcome.\nJust narration: no speaker here? No, \"quoted\".\nmira: lower case\n===\n", "t", PackedStringArray(["mira"]))
	var text: String = result["text"]
	assert_true(text.contains("const old_guide := \"Old Guide\""), text)
	assert_false(text.contains("const mira"), "cast members speak as themselves")
	assert_true(text.contains("\tmira: \"Hi, {name}! {{not a value}}\"\n"), text)
	assert_true(text.contains("\told_guide: \"Welcome.\"\n"), text)
	assert_true(text.contains("var name := 0"), "undeclared variables are declared")
	assert_has(result["notes"], "$name is never declared; it starts as 0.")


func test_expressions() -> void:
	var result := YarnConverter.to_tale("title: A\n---\n<<declare $n = 2 as Number>>\n<<set $ok = $n gte 2 && !($n eq 5) || $n neq 3>>\n<<set $roll to dice(6) + random_range(1, 3)>>\n<<set $r = random()>>\n<<if not $ok xor true>>\nx\n<<endif>>\n===\n")
	var text: String = result["text"]
	assert_true(text.contains("var n := 2\n"), text)
	assert_true(text.contains("\tok = n >= 2 and not (n == 5) or n != 3\n"), text)
	assert_true(text.contains("\troll = randi_range(1, 6) + randi_range(1, 3)\n"), text)
	assert_true(text.contains("\tr = randf()\n"), text)
	assert_true(text.contains("\tif not ok != true:\n"), text)
	assert_true(text.contains("var ok := false\n"), "the start value follows the type assigned")


func test_options_nest_and_continue() -> void:
	var source := "title: Start\n---\n-> One\n    -> Inner A\n        a\n    -> Inner B\n-> Two\n    <<if true>>\n        two\n    <<endif>>\nafter\n===\n"
	var result := _load(source)
	assert_true(result["text"].contains("\tchoose:\n\t\t\"One\":\n\t\t\tchoose:\n\t\t\t\t\"Inner A\":\n\t\t\t\t\t\"a\"\n\t\t\t\t\"Inner B\":\n\t\t\t\t\tpass\n\t\t\"Two\":\n\t\t\tif true:\n\t\t\t\t\"two\"\n\t\"after\"\n"), result["text"])
	presenter.picks = ["One", "Inner B"]
	await director.play("yarn_test")
	assert_eq(presenter.lines, ["after"])


func test_detours_stops_and_odd_names() -> void:
	var source := "title: Start\n---\n<<detour Side Trip>>\nback\n<<stop>>\nnever\n===\ntitle: Side Trip\n---\nside\n<<return>>\n===\ntitle: if\n---\n<<jump {$where}>>\n<<jump Nowhere>>\n===\n"
	var result := YarnConverter.to_tale(source, "t")
	var text: String = result["text"]
	assert_eq(result["beats"], {"Start": "start", "Side Trip": "side_trip", "if": "if_"})
	assert_true(text.contains("@heading(\"Side Trip\")\nbeat side_trip:"), text)
	assert_true(text.contains("\tside_trip()\n\t\"back\"\n\treturn\n"), text)
	assert_true(text.contains("\t# Yarn: <<jump {$where}>>\n"), text)
	assert_has(result["notes"], "Line 16: there is no node 'Nowhere' to jump to.")


func test_comments_and_headers_are_dropped() -> void:
	var result := YarnConverter.to_tale("// file comment\ntitle: Start\ntags: a b\ncolor: blue\n---\nHello. // a comment\nA URL: https://example.com\n===\n")
	assert_true(result["text"].contains("\t\"Hello.\"\n"), result["text"])
	assert_true(result["text"].contains("\ta_url: \"https://example.com\"\n"), result["text"])


func test_import_file_writes_a_tale_once() -> void:
	var folder := "user://yarn_import_test"
	var result := YarnConverter.import_file(SAMPLE, folder)
	assert_eq(result["error"], "")
	assert_eq(result["path"], folder.path_join("lighthouse.tale"))
	assert_eq(result["notes"].size(), 1)
	var text := FileAccess.get_file_as_string(result["path"])
	assert_true(text.contains("visited(\"lighthouse.lamp\")"), "visited() names the new tale")
	var again := YarnConverter.import_file(SAMPLE, folder)
	assert_eq(again["error"], "%s already exists; rename or remove it first." % result["path"])
	assert_eq(YarnConverter.import_file("res://no_such.yarn", folder)["error"], "There is no file res://no_such.yarn.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(result["path"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))

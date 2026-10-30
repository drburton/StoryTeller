extends "res://tests/framework/story_test.gd"
## Runs the TaleScript conformance suite (conformance/, decision 0025) on
## the reference implementation: every check case gives its expected
## problems, and every run case plays its expected transcript. The parse
## cases are run by test_tale_golden.gd. Run the tests with
## "-- --update-conformance" to rewrite the expected files after an
## intended change, then review the diff before committing.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ROOT := "res://conformance"


func _update() -> bool:
	return "--update-conformance" in OS.get_cmdline_user_args()


static func _cases(kind: String) -> PackedStringArray:
	var names := PackedStringArray()
	for file_name in DirAccess.get_files_at(ROOT.path_join(kind)):
		if file_name.ends_with(".tale"):
			names.append(file_name.get_basename())
	names.sort()
	return names


static func _settings(kind: String, case_name: String, extension: String) -> Dictionary:
	var path := ROOT.path_join(kind).path_join(case_name + extension)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _compare(kind: String, case_name: String, actual: String) -> void:
	var expected_path := ROOT.path_join(kind).path_join(case_name + ".expected.txt")
	if _update():
		var file := FileAccess.open(expected_path, FileAccess.WRITE)
		file.store_string(actual)
		file.close()
		return
	if not FileAccess.file_exists(expected_path):
		fail("%s/%s has no expected output. Run the tests with -- --update-conformance." % [kind, case_name])
		return
	assert_eq(actual, FileAccess.get_file_as_string(expected_path), "%s/%s" % [kind, case_name])


# --- check -------------------------------------------------------------------

## The check context a case describes: see conformance/README.md.
static func context_for(settings: Dictionary, tale_name: String) -> TaleCheckContext:
	var context := TaleCheckContext.new()
	context.tale_name = str(settings.get("tale_name", tale_name))
	var actions: Dictionary = settings.get("actions", {})
	for action in actions:
		var spec: Dictionary = actions[action]
		context.add_action(action, PackedStringArray(spec.get("params", [])), int(spec.get("required", 0)))
	for action in settings.get("actions_unchecked", []):
		context.add_action_unchecked(action)
	var cast: Dictionary = settings.get("cast", {})
	for id in cast:
		var entry = cast[id]
		if entry is Dictionary:
			context.add_cast(id, PackedStringArray(entry.get("moods", [])), PackedStringArray(entry.get("fields", [])))
		else:
			context.add_cast(id, PackedStringArray(entry))
	for exposed in settings.get("exposed", []):
		context.add_exposed(exposed)
	var tales: Dictionary = settings.get("tales", {})
	for other in tales:
		context.add_tale(other, PackedStringArray(tales[other].get("beats", [])), PackedStringArray(tales[other].get("vars", [])))
	return context


## The problems the reference implementation finds in a check case, one per
## line: "<line>: <message>", "<line>: warning: <message>", or
## "<line>: parse: <message>".
static func check_case(source: String, settings: Dictionary, tale_name: String) -> String:
	var doc := TaleParser.parse(source)
	var lines := PackedStringArray()
	for diagnostic in doc.diagnostics:
		lines.append("%d: parse: %s" % [diagnostic.line, diagnostic.message])
	for diagnostic in TaleChecker.check(doc, context_for(settings, tale_name)):
		lines.append("%d: %s%s" % [diagnostic.line, "" if diagnostic.is_error() else "warning: ", diagnostic.message])
	return "\n".join(lines) + "\n" if not lines.is_empty() else "(no problems)\n"


func test_check_cases() -> void:
	var names := _cases("check")
	assert_true(names.size() > 0, "check cases found")
	for case_name in names:
		var source := FileAccess.get_file_as_string(ROOT.path_join("check").path_join(case_name + ".tale"))
		_compare("check", case_name, check_case(source, _settings("check", case_name, ".context.json"), case_name))


# --- run ---------------------------------------------------------------------

func test_run_cases() -> void:
	var names := _cases("run")
	assert_true(names.size() > 0, "run cases found")
	for case_name in names:
		var source := FileAccess.get_file_as_string(ROOT.path_join("run").path_join(case_name + ".tale"))
		var transcript := await run_case(source, _settings("run", case_name, ".run.json"), case_name)
		_compare("run", case_name, transcript)


## Plays a run case with the reference director and returns its transcript
## (see conformance/README.md).
func run_case(source: String, settings: Dictionary, tale_name: String) -> String:
	var config := StoryConfig.new()
	config.crew = [TaleDirector]
	var story: Node = StoryScript.new()
	story.start(config)
	tree.root.add_child(story)
	var director := story.get_crew(&"TaleDirector") as TaleDirector
	var player := _Player.new()
	player.picks = Array(settings.get("picks", []))
	tree.root.add_child(player)
	director.presenter = player
	director.skipping = true
	var events := player.events
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		events.append("error: line %d: %s" % [line, message]))
	director.story_signal.connect(func(signal_name: String, value: Variant) -> void:
		events.append("signal: %s %s" % [signal_name, JSON.stringify(value)]))
	var built := TaleCompiler.build(source, tale_name, director.make_check_context(tale_name))
	var tale: Tale = built["tale"]
	for diagnostic in built["diagnostics"]:
		if diagnostic.is_error():
			events.append("compile error: line %d: %s" % [diagnostic.line, diagnostic.message])
	if tale != null:
		director.add_tale(tale)
		await director.play(tale_name, str(settings.get("start", "start")))
		var names := PackedStringArray()
		for variable in tale.variables:
			names.append(str(variable["name"]))
		names.sort()
		for var_name in names:
			events.append("var: %s = %s" % [var_name, JSON.stringify(director.get_var(tale_name, var_name))])
	events.append("end")
	story.shut_down()
	tree.root.remove_child(story)
	story.queue_free()
	tree.root.remove_child(player)
	player.queue_free()
	await tree.process_frame
	return "\n".join(events) + "\n"


## Shows lines at once and picks options from a list: an index, an option's
## text, or -1 to let a timed choice run out. With the list used up, it
## picks the first option it can.
class _Player extends TalePresenter:
	var picks: Array = []
	var events: PackedStringArray = []

	func show_line(line: Dictionary) -> void:
		var speaker := str(line.get("speaker_name", ""))
		events.append("line: %s%s" % ["%s: " % speaker if not speaker.is_empty() else "", line["text"]])
		await get_tree().process_frame

	func choose(options: Array[Dictionary], settings: Dictionary) -> int:
		var texts := PackedStringArray()
		var first := -1
		for i in options.size():
			texts.append(str(options[i]["text"]) if options[i]["enabled"] else "[%s]" % options[i]["text"])
			if first == -1 and options[i]["enabled"]:
				first = i
		events.append("choose: %s%s" % [" | ".join(texts), " (timed)" if float(settings.get("timeout", 0.0)) > 0.0 else ""])
		var pick: int = first
		if not picks.is_empty():
			var wanted = picks.pop_front()
			pick = int(wanted) if wanted is float or wanted is int else Array(texts).find(str(wanted))
		events.append("pick: %s" % (str(options[pick]["text"]) if pick >= 0 and pick < options.size() else "(time runs out)"))
		await get_tree().process_frame
		return pick

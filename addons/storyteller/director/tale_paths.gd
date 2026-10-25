class_name TalePaths
extends Node
## Plays a story down every path, taking each option at every choice, and
## reports what a player could run into: errors, paths that get stuck or go
## round in a loop, and scenes no path reaches. A timed choice is also
## tried with the time running out.
## [codeblock]
## var paths := TalePaths.new()
## add_child(paths)
## var report := await paths.explore(Story.load_config(), "runaway")
## print(TalePaths.describe(report))
## [/codeblock]
## From the command line, see [code]editor/explore_paths.gd[/code].
##
## Each path runs in a story of its own, skipping, so actions finish at once.
## The dialogue box, menus, console, saves, and settings are left out: they
## wait for a player or write files. [code]ask_text()[/code] gets its
## default answer. Objects game code exposes (StoryConfig.exposed_names)
## are stood in for by objects whose methods return null and whose
## properties are 0, unless a crew member answers to the name.

## Stops after this many paths; the report then says it is not complete.
var max_paths := 1000
## A path that makes more choices than this is reported as a loop.
var max_choices := 60
## A path that shows more lines than this without a choice is reported as a loop.
var max_lines := 2000
## A path still running after this many seconds is reported as stuck.
var path_seconds := 10.0

const LEFT_OUT := ["StoryDialogue", "StoryMenus", "StoryConsole", "StorySaves", "StorySettings"]
const StoryScript := preload("res://addons/storyteller/core/story.gd")


## Plays [param tale_name] from [param beat] down every path.
## [param sources] maps tale names to TaleScript text, for tales the
## director doesn't load from the tales folder. Returns [code]{"tale", "paths", "complete", "endings", "problems",
## "unreached"}[/code]: endings counts the paths that end in each scene
## ("tale.beat"), and each problem is [code]{"path", "kind", "message",
## "line"}[/code] with kind "error", "stuck", "loop", or "no_options".
func explore(config: StoryConfig, tale_name: String, beat := "start", sources := {}) -> Dictionary:
	var report := {"tale": tale_name, "paths": 0, "complete": true, "endings": {}, "problems": [], "unreached": PackedStringArray()}
	var stand_ins := _stand_ins(config, sources)
	var tales: Array[Tale] = []
	for source_name in sources:
		var compiled := _compile(config, source_name, sources[source_name], stand_ins)
		if compiled["tale"] == null:
			report["problems"].append_array(compiled["problems"])
			return report
		tales.append(compiled["tale"])
	var entered := {}
	var plan: Array = []
	while true:
		if report["paths"] >= max_paths:
			report["complete"] = false
			break
		var run := await _play_path(config, tale_name, beat, plan, tales, stand_ins)
		report["paths"] += 1
		entered.merge(run["entered"])
		if not run["ending"].is_empty():
			report["endings"][run["ending"]] = report["endings"].get(run["ending"], 0) + 1
		for problem in run["problems"]:
			problem["path"] = run["path"]
			report["problems"].append(problem)
		var next := next_plan(run["trace"])
		if next.is_empty():
			break
		plan = next
	for beat_name in _beats_of(config, tale_name, sources):
		if not entered.has("%s.%s" % [tale_name, beat_name]):
			report["unreached"].append(beat_name)
	return report


## The picks for the next path after the path whose choices were
## [param trace] ([code]{"options", "pick"}[/code] at each choice): the same
## picks up to the last choice with an option not tried yet, then that
## option. Empty when every path has been tried.
static func next_plan(trace: Array) -> Array:
	for k in range(trace.size() - 1, -1, -1):
		var options: Array = trace[k]["options"]
		var at := options.find(trace[k]["pick"])
		if at >= 0 and at + 1 < options.size():
			var plan := []
			for i in k:
				plan.append(trace[i]["pick"])
			plan.append(options[at + 1])
			return plan
	return []


## [param report] in words, for the command line.
static func describe(report: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("%s: %d path%s played%s." % [report["tale"], report["paths"], "" if report["paths"] == 1 else "s",
		"" if report["complete"] else " (stopped early; there are more)"])
	var endings := PackedStringArray()
	for ending in report["endings"]:
		endings.append("%s (%d)" % [ending, report["endings"][ending]])
	lines.append("Endings: %s" % (", ".join(endings) if not endings.is_empty() else "none"))
	if report["unreached"].is_empty():
		lines.append("Every scene is reached.")
	else:
		lines.append("Never reached: %s" % ", ".join(report["unreached"]))
	if report["problems"].is_empty():
		lines.append("No problems found.")
	else:
		# The same problem on many paths shows once, with how many paths
		# meet it and the first of them.
		var groups := {}
		var order := []
		for problem in report["problems"]:
			var key := "%s|%d|%s" % [problem["kind"], problem.get("line", 0), problem["message"]]
			if not groups.has(key):
				groups[key] = {"problem": problem, "count": 0}
				order.append(key)
			groups[key]["count"] += 1
		lines.append("%d problem%s:" % [order.size(), "" if order.size() == 1 else "s"])
		for key in order:
			var problem: Dictionary = groups[key]["problem"]
			var count: int = groups[key]["count"]
			var where := " (line %d)" % problem["line"] if problem.get("line", 0) > 0 else ""
			lines.append("  %s%s: %s" % [problem["kind"], where, problem["message"]])
			var path := " > ".join(problem["path"]) if not problem["path"].is_empty() else "(no choices)"
			lines.append("    on %d path%s, first after: %s" % [count, "" if count == 1 else "s", path] if count > 1 else "    after: %s" % path)
	return "\n".join(lines)


func _play_path(config: StoryConfig, tale_name: String, beat: String, plan: Array, tales: Array[Tale], stand_ins: Dictionary) -> Dictionary:
	var run := {"trace": [], "path": PackedStringArray(), "entered": {}, "ending": "", "problems": []}
	var story: Node = StoryScript.new()
	story.start(_config_for_paths(config))
	add_child(story)
	var director := story.get_crew(&"TaleDirector") as TaleDirector
	var player := _Player.new()
	player.plan = plan
	player.director = director
	player.max_choices = max_choices
	player.max_lines = max_lines
	add_child(player)
	director.presenter = player
	director.skipping = true
	for tale in tales:
		director.add_tale(tale)
	for exposed_name in stand_ins:
		story.expose(exposed_name, stand_ins[exposed_name][0], stand_ins[exposed_name][1], stand_ins[exposed_name][2])
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		run["problems"].append({"kind": "error", "message": message, "line": line}))
	director.beat_entered.connect(func(entered_tale: String, entered_beat: String) -> void:
		var id := "%s.%s" % [entered_tale, entered_beat]
		run["entered"][id] = true
		run["ending"] = id)
	var done := [false]
	(func() -> void:
		await story.play(tale_name, beat)
		done[0] = true).call()
	var started := Time.get_ticks_msec()
	while not done[0] and not player.stopped:
		if Time.get_ticks_msec() - started > path_seconds * 1000.0:
			run["problems"].append({"kind": "stuck", "message": "still playing after %d seconds, maybe waiting on something that never finishes" % path_seconds, "line": 0})
			break
		await get_tree().process_frame
	if player.stopped:
		run["problems"].append({"kind": player.stop_kind, "message": player.stop_reason, "line": 0})
	# A path cut short has no ending.
	if not done[0] or player.stopped:
		director.stop()
		run["ending"] = ""
	run["trace"] = player.trace
	for step in player.trace:
		run["path"].append(step["texts"].get(step["pick"], "(time runs out)"))
	story.shut_down()
	remove_child(story)
	story.queue_free()
	remove_child(player)
	player.queue_free()
	await get_tree().process_frame
	return run


# The project's config without the members that wait for a player or write
# files, and with a menus member that answers ask_text() by itself.
func _config_for_paths(config: StoryConfig) -> StoryConfig:
	var copy := config.duplicate() as StoryConfig
	var crew: Array[Script] = []
	for script in config.crew:
		if script != null and script.get_global_name() not in LEFT_OUT:
			crew.append(script)
	crew.append(_Answers)
	copy.crew = crew
	copy.autosave_on_choice = false
	return copy


# Stand-ins for the names game code exposes and no crew member answers to,
# with the methods and properties the tales use on them.
func _stand_ins(config: StoryConfig, sources: Dictionary) -> Dictionary:
	var answered := {}
	var probe: Node = StoryScript.new()
	probe.start(_config_for_paths(config))
	for member in probe.get_children():
		if member.has_method("get_tale_names"):
			for answered_name in member.get_tale_names():
				answered[answered_name] = true
	probe.shut_down()
	probe.free()
	var sources_text := PackedStringArray()
	for file_name in StoryAssets.list_names(config.tales_folder, ["tale"]):
		sources_text.append(FileAccess.get_file_as_string(config.tales_folder.path_join(file_name + ".tale")))
	sources_text.append_array(PackedStringArray(sources.values()))
	var text := "\n".join(sources_text)
	var stand_ins := {}
	for exposed_name in config.exposed_names:
		if answered.has(exposed_name):
			continue
		var methods := PackedStringArray()
		var properties := PackedStringArray()
		var used := RegEx.create_from_string("\\b%s\\.(\\w+)(\\s*\\()?" % exposed_name)
		for found in used.search_all(text):
			var member := found.get_string(1)
			var list := methods if not found.get_string(2).is_empty() else properties
			if member not in list:
				list.append(member)
		var source := "extends RefCounted\n"
		for property in properties:
			source += "var %s = 0\n" % property
		for method in methods:
			source += "func %s(a = null, b = null, c = null, d = null, e = null, f = null):\n\treturn null\n" % method
		var script := GDScript.new()
		script.source_code = source
		if script.reload() == OK:
			stand_ins[exposed_name] = [script.new(), methods, properties]
	return stand_ins


# The tale [param source_name] compiled from [param source], or its
# mistakes as problems.
func _compile(config: StoryConfig, source_name: String, source: String, stand_ins: Dictionary) -> Dictionary:
	var probe: Node = StoryScript.new()
	probe.start(_config_for_paths(config))
	var director := probe.get_crew(&"TaleDirector") as TaleDirector
	var context := director.make_check_context(source_name)
	for exposed_name in config.exposed_names:
		context.add_exposed(exposed_name)
	for exposed_name in stand_ins:
		context.add_exposed(exposed_name)
	var built := TaleCompiler.build(source, source_name, context)
	probe.shut_down()
	probe.free()
	var problems := []
	for diagnostic in built["diagnostics"]:
		if diagnostic.is_error():
			problems.append({"kind": "error", "message": diagnostic.message, "line": diagnostic.line, "path": PackedStringArray()})
	return {"tale": built["tale"] if problems.is_empty() else null, "problems": problems}


func _beats_of(config: StoryConfig, tale_name: String, sources: Dictionary) -> PackedStringArray:
	var source: String = sources.get(tale_name, "")
	if source.is_empty():
		source = FileAccess.get_file_as_string(config.tales_folder.path_join(tale_name + ".tale"))
	var beats := PackedStringArray()
	for statement in TaleParser.parse(source).statements:
		if statement.kind == TaleNode.Kind.BEAT:
			beats.append(statement.name)
	return beats


## Plays lines at once and picks options from the plan, then the first
## option not tried yet.
class _Player extends TalePresenter:
	var plan: Array = []
	var trace: Array = []
	var director: TaleDirector
	var max_choices := 60
	var max_lines := 2000
	var stopped := false
	var stop_kind := ""
	var stop_reason := ""
	var _lines_since_choice := 0

	func show_line(_line: Dictionary) -> void:
		_lines_since_choice += 1
		if _lines_since_choice > max_lines:
			_stop("loop", "more than %d lines without a choice, maybe a loop" % max_lines)
		await get_tree().process_frame

	func choose(options: Array[Dictionary], settings: Dictionary) -> int:
		_lines_since_choice = 0
		var picks := []
		var texts := {}
		for i in options.size():
			if options[i]["enabled"]:
				picks.append(i)
			texts[i] = str(options[i]["text"])
		if float(settings.get("timeout", 0.0)) > 0.0:
			picks.append(-1)
		if picks.is_empty():
			_stop("no_options", "a choice with no option the player can pick")
			await get_tree().process_frame
			return -1
		if stopped or trace.size() >= max_choices:
			_stop("loop", "more than %d choices, maybe a loop" % max_choices)
			await get_tree().process_frame
			return -1
		var depth := trace.size()
		var pick: int = plan[depth] if depth < plan.size() else picks[0]
		trace.append({"options": picks, "pick": pick, "texts": texts})
		director.skipping = true
		await get_tree().process_frame
		return pick

	# Ends the path: the director stops, so a loop can't keep it busy.
	func _stop(kind: String, reason: String) -> void:
		if not stopped:
			stopped = true
			stop_kind = kind
			stop_reason = reason
			director.stop()


## Answers ask_text() with its default (or "Tester") instead of showing a
## text box.
class _Answers extends StoryMenus:
	func setup(_config: StoryConfig) -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _unhandled_input(_event: InputEvent) -> void:
		pass

	func ask_text(_prompt: String, default_text := "", _max_length := 24) -> String:
		return default_text if not default_text.is_empty() else "Tester"

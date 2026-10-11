extends "res://tests/framework/story_test.gd"
## Tests for TaleDirector and TaleEvaluator, running real tales headless.

const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const EngineClock := preload("res://tests/fixtures/engine_clock.gd")

var director: TaleDirector
var presenter: ScriptedPresenter
var errors: Array[String] = []


func before_each() -> void:
	director = track(TaleDirector.new())
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(director)
	tree.root.add_child(presenter)
	director.presenter = presenter
	errors.clear()
	director.runtime_error.connect(func(message: String, tale_name: String, line: int) -> void:
		errors.append("%s:%d: %s" % [tale_name, line, message]))


## Compiles and registers a tale; fails the test on compile errors.
func _add(tale_name: String, source: String) -> void:
	var result := TaleCompiler.build(source, tale_name, director.make_check_context(tale_name))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail("%s: %s" % [tale_name, diagnostic])
	if result["tale"]:
		director.add_tale(result["tale"])


func _play(source: String, picks: Array = []) -> Array[String]:
	_add("main", source)
	presenter.picks = picks
	await director.play("main")
	return presenter.lines


func test_lines_speakers_and_interpolation() -> void:
	var lines := await _play("const GUIDE := \"Old Guide\"\nconst mira := \"Mira\"\nvar gold := 3\nbeat start:\n\t\"Rain falls.\"\n\tGUIDE: \"You have {gold * 2} coins.\"\n\tmira (sad): \"Hi.\"\n")
	assert_eq(lines, ["Rain falls.", "Old Guide: You have 6 coins.", "Mira: Hi."])
	assert_eq(presenter.line_data[2]["mood"], "sad")
	assert_eq(presenter.line_data[2]["speaker_id"], "mira")
	assert_eq(presenter.line_data[1]["source_line"], 6)
	assert_eq(errors, [])


func test_variables_and_control_flow() -> void:
	var source := "var n := 0\nvar log := []\nbeat start:\n\twhile n < 5:\n\t\tn += 1\n\t\tif n == 2:\n\t\t\tcontinue\n\t\telif n == 4:\n\t\t\tbreak\n\t\tlog.append(n)\n\tfor letter in \"ab\":\n\t\tlog.append(letter)\n\tmatch n:\n\t\t1, 2: \"low\"\n\t\t4 when log.size() == 4: \"four {log}\"\n\t\t_: \"other\"\n"
	var lines := await _play(source)
	assert_eq(lines, ["four [1, 3, \"a\", \"b\"]"])
	assert_eq(director.get_var("main", "n"), 4)
	assert_eq(errors, [])


func test_locals_and_value_parts() -> void:
	var lines := await _play("beat start:\n\tvar pos := Vector2(1, 2)\n\tpos.x = 5\n\tvar bag := {\"a\": 1}\n\tbag[\"b\"] = 2\n\tbag.a += 10\n\tvar items := [1, 2]\n\titems[0] = 9\n\t\"{pos} {bag} {items} {len(items)}\"\n")
	assert_eq(lines, ["(5.0, 2.0) { \"a\": 11, \"b\": 2 } [9, 2] 2"])
	assert_eq(errors, [])


func test_choices() -> void:
	var source := "var tries := 0\nvar has_key := false\nbeat start:\n\ttries += 1\n\tchoose(style = \"list\"):\n\t\t@once \"Look around\":\n\t\t\thas_key = true\n\t\t\tjump start\n\t\t\"Open door\" if has_key:\n\t\t\t\"Opened after {tries} tries.\"\n\t\t@show_disabled \"Fly\" if false:\n\t\t\tpass\n"
	var lines := await _play(source, ["Look around", "Open door"])
	assert_eq(presenter.offered, [["Look around", "[Fly]"], ["Open door", "[Fly]"]])
	assert_eq(presenter.settings[0], {"style": "list"})
	assert_eq(lines, ["Opened after 2 tries."])


func test_choice_timeout() -> void:
	var lines := await _play("beat start:\n\tchoose(timeout = 1.0):\n\t\t\"A\": \"chose A\"\n\t\ttimeout: \"too slow\"\n\t\"after\"\n", [-1])
	assert_eq(lines, ["too slow", "after"])


func test_beat_calls_jumps_and_returns() -> void:
	_add("other", "var flag := false\nbeat start:\n\t\"other start\"\nbeat helper:\n\tflag = true\n\t\"other helper\"\n")
	var source := "beat start:\n\t\"one\"\n\tlocal_help()\n\tother.helper()\n\t\"back {other.flag}\"\n\tjump finale\n\t\"never\"\nbeat local_help:\n\t\"in helper\"\n\treturn\n\t\"never\"\nbeat finale:\n\t\"done {visited(\\\"other.helper\\\")}\"\n"
	var lines := await _play(source)
	assert_eq(lines, ["one", "in helper", "other helper", "back true", "done true"])
	assert_eq(errors, [])


func test_jump_to_other_tale() -> void:
	_add("other", "beat start:\n\t\"other start\"\n")
	var lines := await _play("beat start:\n\tjump other.start\n")
	assert_eq(lines, ["other start"])


func test_actions_and_signals() -> void:
	var signals := []
	director.story_signal.connect(func(signal_name: String, value: Variant) -> void: signals.append([signal_name, value]))
	var clock: EngineClock = track(EngineClock.new())
	tree.root.add_child(clock)
	var started: float = await clock.start()
	var signal_times := []
	director.story_signal.connect(func(_signal_name: String, _value: Variant) -> void: signal_times.append(clock.seconds))
	var lines := await _play("beat start:\n\twait(0.05)\n\t\"after wait\"\n\tawait wait(seconds = 0.05)\n\temit(\"door\", 3)\n\temit(\"bell\")\n")
	assert_eq(lines, ["after wait"])
	assert_eq(signals, [["door", 3], ["bell", null]])
	assert_true(signal_times[0] - started >= 0.099, "both waits happened")


func test_exposed_objects_are_sandboxed() -> void:
	var inventory := Node.new()
	inventory.name = "Inv"
	track(inventory)
	director.expose("inventory", inventory, ["get_child_count"], ["name"])
	director.expose_function("double", func(x: int) -> int: return x * 2)
	var lines := await _play("beat start:\n\t\"{inventory.name} {inventory.get_child_count()} {double(4)}\"\n\tinventory.queue_free()\n\t\"still here\"\n")
	assert_eq(lines, ["Inv 0 8", "still here"])
	assert_eq(errors, ["main:3: 'queue_free' is not available to tales."])
	assert_false(inventory.is_queued_for_deletion())


func test_runtime_errors_are_reported_and_skipped() -> void:
	var lines := await _play("var x := \"text\"\nbeat start:\n\tx = x + 1\n\t\"next\"\n\tvar list := [1]\n\tlist[5] = 0\n\t\"end\"\n")
	assert_eq(lines, ["next", "end"])
	assert_eq(errors, ["main:3: Can't use '+' with String and int.", "main:6: Index 5 is outside the array (size 1)."])


func test_endless_loop_is_stopped() -> void:
	director.max_steps_without_pause = 500
	var lines := await _play("beat start:\n\twhile true:\n\t\tpass\n\t\"never\"\n")
	assert_eq(lines, [])
	assert_eq(errors.size(), 1)
	assert_true(errors[0].contains("endless loop"))
	assert_false(director.is_playing())


func test_type_constants() -> void:
	var lines := await _play("beat start:\n\t\"{Color.RED} {Vector2.LEFT} {Vector3.UP}\"\n\tvar x := Color.NOT_A_COLOR\n")
	assert_eq(lines, ["(1.0, 0.0, 0.0, 1.0) (-1.0, 0.0) (0.0, 1.0, 0.0)"])
	assert_eq(errors, ["main:3: Color has no constant 'NOT_A_COLOR'."])


func test_global_variables() -> void:
	await _play("@global var endings := 0\nbeat start:\n\tendings += 1\n")
	assert_eq(JSON.to_native(director.capture_globals()["vars"]), {"endings": 1})
	director.clear()
	await director.play("main")
	assert_eq(JSON.to_native(director.capture_globals()["vars"]), {"endings": 2}, "globals survive a new game")


func test_capture_and_restore_mid_story() -> void:
	var source := "var count := 0\nbeat start:\n\tvar local := \"L\"\n\tfor i in 3:\n\t\tcount += 1\n\t\t\"line {i} {local} {count}\"\n\t\"end\"\n"
	_add("main", source)
	var saved := {}
	presenter.on_line = func(line: Dictionary) -> void:
		if line["text"] == "line 1 L 2" and saved.is_empty():
			saved.merge(JSON.parse_string(JSON.stringify(director.capture())))
	await director.play("main")
	assert_eq(presenter.lines, ["line 0 L 1", "line 1 L 2", "line 2 L 3", "end"])

	var second: TaleDirector = track(TaleDirector.new())
	var second_presenter: ScriptedPresenter = track(ScriptedPresenter.new())
	tree.root.add_child(second)
	tree.root.add_child(second_presenter)
	second.presenter = second_presenter
	second.add_tale(director.get_tale("main"))
	second.restore(saved)
	await second.resume()
	assert_eq(second_presenter.lines, ["line 1 L 2", "line 2 L 3", "end"], "shows the saved line again, then continues")


func test_stop_ends_playback() -> void:
	_add("main", "beat start:\n\t\"one\"\n\t\"two\"\n")
	presenter.on_line = func(_line: Dictionary) -> void: director.stop()
	await director.play("main")
	assert_eq(presenter.lines, ["one"])
	assert_false(director.is_playing())


func test_missing_tale_or_beat() -> void:
	await director.play("nope")
	_add("main", "beat start:\n\tpass\n")
	await director.play("main", "middle")
	assert_eq(errors.size(), 2)
	assert_true(errors[0].contains("not found"))
	assert_true(errors[1].contains("no beat 'middle'"))


func test_check_context_lists_actions() -> void:
	var context := director.make_check_context()
	assert_eq(context.actions["wait"], {"params": PackedStringArray(["seconds"]), "required": 1})
	assert_eq(context.actions["emit"], {"params": PackedStringArray(["signal_name", "value"]), "required": 1})


func test_no_wait_lines_show_while_actions_run() -> void:
	var clock: EngineClock = track(EngineClock.new())
	tree.root.add_child(clock)
	var started := {"at": await clock.start()}
	var shown := {}
	presenter.on_line = func(line: Dictionary) -> void: shown[line["text"]] = clock.seconds - started["at"]
	await _play("beat start:\n\twait(0.2)\n\t@no_wait \"at once\"\n\t\"after the wait\"\n")
	assert_true(shown["at once"] < 0.15, "@no_wait shows the line at once: %s" % shown)
	assert_true(shown["after the wait"] >= 0.19, "the next line still waits: %s" % shown)
	director.wait_for_actions = false
	presenter.lines.clear()
	shown.clear()
	started["at"] = clock.seconds
	await _play("beat start:\n\twait(0.2)\n\t\"no waiting\"\n")
	assert_true(shown["no waiting"] < 0.15, "the project switch turns waiting off: %s" % shown)


func test_no_wait_is_checked() -> void:
	var result := TaleCompiler.build("@no_wait\nbeat start:\n\t@no_wait(1) \"x\"\n\t@no_wait choose:\n\t\t\"a\":\n\t\t\tpass\n", "main", director.make_check_context("main"))
	var messages: Array = result["diagnostics"].map(func(d: TaleDiagnostic) -> String: return d.message)
	assert_has(messages, "@no_wait only applies to dialogue, narration, and choose.")
	assert_has(messages, "@no_wait takes no arguments.")
	assert_eq(messages.size(), 2, str(messages))
	var tale: Tale = TaleCompiler.build("beat start:\n\t@no_wait choose:\n\t\t\"a\":\n\t\t\tpass\n", "main", director.make_check_context("main"))["tale"]
	assert_true(tale.instructions.any(func(i: Dictionary) -> bool: return i["op"] == "choose" and i.get("no_wait", false)), "choose carries the flag")


func test_tales_load_from_a_folder_outside_the_project() -> void:
	var folder := "user://test_mods"
	DirAccess.make_dir_recursive_absolute(folder)
	var files := {
		"mod_a.tale": "var visits := 1\n\nbeat start:\n\t\"A mod line, visit {visits}.\"\n\tmod_b.greet()\n\tjump mod_b.finish\n",
		"mod_b.tale": "beat greet:\n\t\"Hello from b, after {mod_a.visits} visit.\"\n\nbeat finish:\n\t\"The end.\"\n",
		"broken.tale": "beat start:\n\tjump nowhere\n",
	}
	for file_name in files:
		var file := FileAccess.open(folder.path_join(file_name), FileAccess.WRITE)
		file.store_string(files[file_name])
		file.close()
	var problems := director.load_tale_folder(folder)
	assert_eq(problems.size(), 1, str(problems))
	assert_true(problems[0].begins_with("user://test_mods/broken.tale:2:"), problems[0])
	await director.play("mod_a")
	assert_eq(presenter.lines, ["A mod line, visit 1.", "Hello from b, after 1 visit.", "The end."])
	assert_eq(director.get_tale("mod_a").source_path, "user://test_mods/mod_a.tale", "live reload can find the file")
	for file_name in files:
		DirAccess.remove_absolute(folder.path_join(file_name))
	assert_eq(director.load_tale_folder("user://no_such_mods"), PackedStringArray())

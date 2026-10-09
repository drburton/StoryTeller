class_name TaleDirector
extends StoryCrew
## Runs tales: steps through instructions, keeps variables and the call
## stack, calls actions, and hands lines and choices to the presenter.
##
## [codeblock]
## var director: TaleDirector = Story.get_crew(&"TaleDirector")
## await director.play("prologue")
## [/codeblock]

## Emitted when a tale starts playing from [method play].
signal story_started(tale_name: String, beat: String)
## Emitted when playback ends: the last beat finished or [method stop] ran.
signal story_finished
## Emitted when a beat starts, including beat calls and jumps.
signal beat_entered(tale_name: String, beat: String)
## Emitted for every line, before the presenter shows it.
signal line_started(line: Dictionary)
## Emitted when the player continues past a line.
signal line_finished(line: Dictionary)
## Emitted before the presenter shows choices.
signal choice_started(options: Array[Dictionary])
## Emitted after the player picks an option.
signal choice_made(option: Dictionary)
## Emitted when a line marked @no_rewind runs: rewinding must not go past it.
signal rewind_barrier
## Emitted by [code]emit("name", value)[/code] in tales.
signal story_signal(signal_name: String, value: Variant)
## Emitted when a tale does something invalid at runtime. The director
## reports it and continues with the next instruction.
signal runtime_error(message: String, tale_name: String, line: int)
## Emitted after live reload swaps in a new version of a tale.
signal tale_reloaded(tale_name: String)
## Emitted when an edited tale has errors and the old version keeps running.
signal reload_failed(tale_name: String, message: String)

## Stage positions available to tales, as fractions of the screen width.
const POSITIONS := {
	"LEFT": Vector2(0.25, 0.0),
	"CENTER": Vector2(0.5, 0.0),
	"RIGHT": Vector2(0.75, 0.0),
}
const BUILTIN_ACTIONS := [
	preload("res://addons/storyteller/actions/action_wait.gd"),
	preload("res://addons/storyteller/actions/action_emit.gd"),
	preload("res://addons/storyteller/actions/action_backdrop.gd"),
	preload("res://addons/storyteller/actions/action_prop.gd"),
	preload("res://addons/storyteller/actions/action_hide_prop.gd"),
	preload("res://addons/storyteller/actions/action_clear_props.gd"),
	preload("res://addons/storyteller/actions/action_cg.gd"),
	preload("res://addons/storyteller/actions/action_hide_cg.gd"),
	preload("res://addons/storyteller/actions/action_shake.gd"),
	preload("res://addons/storyteller/actions/action_music.gd"),
	preload("res://addons/storyteller/actions/action_stop_music.gd"),
	preload("res://addons/storyteller/actions/action_sound.gd"),
	preload("res://addons/storyteller/actions/action_ambience.gd"),
	preload("res://addons/storyteller/actions/action_stop_ambience.gd"),
	preload("res://addons/storyteller/actions/action_voice.gd"),
	preload("res://addons/storyteller/actions/action_stop_audio.gd"),
	preload("res://addons/storyteller/actions/action_ask_text.gd"),
	preload("res://addons/storyteller/actions/action_ask_number.gd"),
	preload("res://addons/storyteller/actions/action_dialogue_style.gd"),
	preload("res://addons/storyteller/actions/action_clear_page.gd"),
	preload("res://addons/storyteller/actions/action_hide_dialogue.gd"),
	preload("res://addons/storyteller/actions/action_flash.gd"),
	preload("res://addons/storyteller/actions/action_fade_out.gd"),
	preload("res://addons/storyteller/actions/action_fade_in.gd"),
	preload("res://addons/storyteller/actions/action_weather.gd"),
	preload("res://addons/storyteller/actions/action_filter.gd"),
	preload("res://addons/storyteller/actions/action_exit_all.gd"),
	preload("res://addons/storyteller/actions/action_autosave.gd"),
	preload("res://addons/storyteller/actions/action_collect.gd"),
	preload("res://addons/storyteller/actions/action_play_movie.gd"),
]
## Actions whose first argument names an asset that can be loaded ahead.
const PRELOAD_ACTIONS := ["backdrop", "prop", "cg", "music", "sound", "ambience", "voice"]
## How many instructions of a beat are scanned for assets to preload.
const PRELOAD_SCAN_LIMIT := 400

## Seconds between checks for edited tale files when live reload is on.
const LIVE_RELOAD_INTERVAL := 1.0

## Upper limit of instructions run without showing a line or choice, which
## stops endless loops from freezing the game.
var max_steps_without_pause := 100_000

## Object that shows lines and choices: a [TalePresenter] or any object with
## the same methods. When null, the "Dialogue" crew member is used.
var presenter: Object
## True while the player is skipping. Actions finish instantly.
var skipping := false

## Folder where [method get_tale] looks for "<name>.tale".
var tales_folder := "res://story/tales"
## Reload tales whose source file changes while the game runs, and continue
## at the same line. On in debug builds; it only finds source files when the
## game runs from the project folder (for example from the editor).
var live_reload := OS.is_debug_build()
## Language the tales are written in. Lines are shown as written while the
## game's locale is this language.
var source_language := "en"
## Named text styles from [member StoryConfig.text_styles], expanded in
## every line before it is shown.
var text_styles: Dictionary = {}

var _tales: Dictionary = {}
var _story_vars: Dictionary = {}
var _global_vars: Dictionary = {}
var _constants: Dictionary = {}
var _actions: Dictionary = {}
var _exposed: Dictionary = {}
var _visited: Dictionary = {}
var _once_chosen: Dictionary = {}
var _stack: Array[TaleFrame] = []
var _pending: Array[TaleTask] = []
var _evaluator: TaleEvaluator
var _context: TaleContext
var _playing := false
## Index of the say or choose instruction the player is looking at, or -1.
## Saves record it so loading shows the same line again.
var _line_pc := -1
## Expressions of the [act] and [sound] tags in the line on screen, and the
## frame they run in (see [method run_text_act]).
var _text_acts: Array = []
var _text_frame: TaleFrame
## Line ids the player has seen, kept across playthroughs.
var _read_lines: Dictionary = {}
## Beats entered and choice options seen and picked, kept across
## playthroughs for the route chart.
var routes := RouteLog.new()
## Translated text to its compiled parts.
var _translated: Dictionary = {}
## Names from [member StoryConfig.exposed_names].
var _declared_names := PackedStringArray()
## Source path to modified time, for live reload.
var _source_times: Dictionary = {}
var _reload_timer := 0.0
## Tale and line of the instruction being run, for error reports.
var _current_tale := ""
var _current_line := 0
## Increases on every play or stop, so an old run loop knows to quit.
var _generation := 0


func _init() -> void:
	_evaluator = TaleEvaluator.new(self)
	_context = TaleContext.new(self)
	for script in BUILTIN_ACTIONS:
		add_action(script.new())


func setup(config: StoryConfig) -> void:
	for action in StoryConfig.make_actions(config.actions):
		add_action(action)
	tales_folder = config.tales_folder
	source_language = config.source_language
	text_styles = config.text_styles
	_declared_names = config.exposed_names


func clear() -> void:
	stop()
	_story_vars.clear()
	_constants.clear()
	_visited.clear()
	_once_chosen.clear()


# --- Public API -------------------------------------------------------------

## Plays [param tale_name] from [param beat]. Awaitable: returns when the
## story finishes or is stopped. Loading a save while playing does not end it.
func play(tale_name: String, beat := "start") -> void:
	stop()
	var generation := _generation
	var tale := get_tale(tale_name)
	if tale == null:
		_report("Tale '%s' was not found in %s." % [tale_name, tales_folder], tale_name, 0)
		return
	if tale.get_beat_start(beat) < 0:
		_report("Tale '%s' has no beat '%s'." % [tale_name, beat], tale_name, 0)
		return
	await _prepare_tale(tale)
	if generation != _generation:
		return
	_stack.append(_enter_beat(tale, beat))
	_playing = true
	story_started.emit(tale_name, beat)
	_run(generation)
	if _playing:
		await story_finished


## Stops playback. A [method play] in progress returns.
func stop() -> void:
	_halt()
	if _playing:
		_playing = false
		story_finished.emit()


## Jumps straight to [param beat] of [param tale_name], keeping variables,
## and plays from there. Meant for tools like the debug console. Awaitable.
## Returns an error message or "".
func jump_to(tale_name: String, beat := "start") -> String:
	var tale := get_tale(tale_name)
	if tale == null:
		return "Tale '%s' was not found in %s." % [tale_name, tales_folder]
	if tale.get_beat_start(beat) < 0:
		return "Tale '%s' has no beat '%s'." % [tale_name, beat]
	_halt()
	_playing = false
	await _prepare_tale(tale)
	_stack.append(_enter_beat(tale, beat))
	resume()
	return ""


## Evaluates a TaleScript expression where the story is now, for tools like
## the debug console. Awaitable. Returns [code][true, value][/code] or
## [code][false, error message][/code].
func evaluate_source(source: String) -> Array:
	var parsed := TaleParser.parse_expression(source)
	if parsed["error"]:
		return [false, parsed["error"]]
	var compiled := TaleCompiler.compile_text("{%s}" % source)
	if not compiled["errors"].is_empty() or compiled["parts"].size() != 1 or compiled["parts"][0] is String:
		return [false, "Can't evaluate '%s'." % source]
	var evaluator := TaleEvaluator.new(self)
	var frame: TaleFrame = _stack.back() if not _stack.is_empty() else null
	var value: Variant = await evaluator.evaluate(compiled["parts"][0], frame)
	if evaluator.failed():
		return [false, evaluator.error]
	return [true, value]


## Runs the [code][act=N][/code] or [code][sound=N][/code] tag number
## [param index] of the line on screen. The dialogue box calls this when
## typing reaches the tag. Awaitable: it returns once the expression is
## evaluated, so [code][act=await wait(1)][/code] holds the typing.
func run_text_act(index: int) -> void:
	if index < 0 or index >= _text_acts.size() or _text_frame == null:
		return
	var generation := _generation
	var frame := _text_frame
	var evaluator := TaleEvaluator.new(self)
	await evaluator.evaluate(_text_acts[index], frame)
	if evaluator.failed() and generation == _generation:
		_report(evaluator.error, frame.tale.tale_name, _current_line)


## Where the story is: [code]{"tale", "beat", "line"}[/code] (source line),
## or an empty dictionary when nothing plays.
func get_position() -> Dictionary:
	if _stack.is_empty():
		return {}
	var frame: TaleFrame = _stack.back()
	var pc := _line_pc if _line_pc >= 0 else frame.pc
	var line := 0
	if pc >= 0 and pc < frame.tale.instructions.size():
		line = frame.tale.instructions[pc]["line"]
	return {"tale": frame.tale.tale_name, "beat": frame.beat, "line": line}


## Variables visible where the story is: the current tale's story variables
## and every global variable.
func get_variables() -> Dictionary:
	var result := {}
	var position := get_position()
	if not position.is_empty():
		result.merge(_story_vars.get(position["tale"], {}))
	result.merge(_global_vars)
	return result


## Recompiles [param tale_name] from its source file and swaps it in. If
## the story is inside that tale, it continues at the same line (matched by
## line id, or else by source line). Awaitable. Returns an error message or
## "" on success; on error the old version keeps running.
func reload_tale(tale_name: String) -> String:
	var old: Tale = _tales.get(tale_name)
	if old == null or old.source_path.is_empty() or not FileAccess.file_exists(old.source_path):
		return "Tale '%s' has no source file to reload." % tale_name
	var result := TaleCompiler.build(FileAccess.get_file_as_string(old.source_path), tale_name, make_check_context(tale_name), old.source_path)
	_source_times[old.source_path] = FileAccess.get_modified_time(old.source_path)
	if result["tale"] == null:
		for diagnostic in result["diagnostics"]:
			if diagnostic.is_error():
				return "%s:%d: %s" % [old.source_path, diagnostic.line, diagnostic.message]
		return "%s could not be compiled." % old.source_path
	var tale: Tale = result["tale"]
	var state := capture()
	var inside := false
	for saved in state["stack"]:
		if saved["tale"] != tale_name:
			continue
		inside = true
		var pc := _map_pc(old, tale, saved["beat"], int(saved["pc"]))
		if pc < 0:
			return "Beat '%s' is gone from %s, so the story can't continue there." % [saved["beat"], old.source_path]
		saved["pc"] = pc
	_tales[tale_name] = tale
	if _story_vars.has(tale_name):
		await _add_new_variables(tale)
	if inside and _playing:
		restore(state)
		resume()
	tale_reloaded.emit(tale_name)
	return ""


## Ends the current run loop without finishing the story, and releases the
## presenter if it is waiting for the player.
func _halt() -> void:
	_generation += 1
	_stack.clear()
	_pending.clear()
	_line_pc = -1
	var target := _get_presenter()
	if target != null and target.has_method("cancel"):
		target.cancel()


func is_playing() -> bool:
	return _playing


## Registers a compiled tale, replacing one with the same name.
func add_tale(tale: Tale) -> void:
	_tales[tale.tale_name] = tale


## Returns the tale called [param tale_name], loading it from
## [member tales_folder] when needed, or null.
func get_tale(tale_name: String) -> Tale:
	if _tales.has(tale_name):
		return _tales[tale_name]
	var path := tales_folder.path_join(tale_name + ".tale")
	if not ResourceLoader.exists(path):
		return null
	var tale := load(path) as Tale
	if tale != null:
		_tales[tale_name] = tale
	return tale


## Registers an action so tales can call it.
func add_action(action: TaleAction) -> void:
	_actions[action.get_action_name()] = action


func get_action(action_name: String) -> TaleAction:
	return _actions.get(action_name)


## Makes [param object] available to tales as [param exposed_name], limited to
## the given [param methods] and readable/writable [param properties].
func expose(exposed_name: String, object: Object, methods: PackedStringArray = [], properties: PackedStringArray = []) -> void:
	_exposed[exposed_name] = TaleExposed.new(object, methods, properties)


## Makes [param callable] available to tales as a function called [param function_name].
func expose_function(function_name: String, callable: Callable) -> void:
	_exposed[function_name] = callable


## Returns the value of a story or global variable, or null.
func get_var(tale_name: String, var_name: String) -> Variant:
	return get_tale_var(tale_name, var_name)[1]


## Builds a [TaleCheckContext] from the registered actions, exposed names,
## and loaded tales, for checking tales against this director.
func make_check_context(tale_name := "") -> TaleCheckContext:
	var context := TaleCheckContext.new()
	context.tale_name = tale_name
	for action_name in _actions:
		var action: TaleAction = _actions[action_name]
		context.add_action(action_name, action.get_parameters(), action.get_required_count())
	for exposed_name in _exposed:
		context.add_exposed(exposed_name)
	for declared in _declared_names:
		context.add_exposed(declared)
	for crew in _crew_siblings():
		if crew.has_method("get_tale_names"):
			for extra in crew.get_tale_names():
				context.add_exposed(extra)
		if crew.has_method("get_cast_moods"):
			var cast: Dictionary = crew.get_cast_moods()
			var fields: Dictionary = crew.get_cast_fields() if crew.has_method("get_cast_fields") else {}
			for id in cast:
				context.add_cast(id, cast[id], fields.get(id, PackedStringArray()))
	for other in _tales:
		var tale: Tale = _tales[other]
		var vars := PackedStringArray()
		for variable in tale.variables:
			vars.append(variable["name"])
		context.add_tale(other, PackedStringArray(tale.beats.keys()), vars)
	return context


# --- Saves --------------------------------------------------------------------

func capture() -> Dictionary:
	var frames: Array = []
	for i in _stack.size():
		var frame := _stack[i]
		var top := i == _stack.size() - 1
		frames.append({
			"tale": frame.tale.tale_name,
			"beat": frame.beat,
			"pc": _line_pc if top and _line_pc >= 0 else frame.pc,
			"locals": JSON.from_native(frame.locals),
			"iterators": JSON.from_native(frame.iterators),
		})
	return {
		"stack": frames,
		"vars": JSON.from_native(_story_vars),
		"visited": _visited.keys(),
		"once": _once_chosen.keys(),
	}


## Replaces the story state with [param data] from [method capture]. Call
## [method resume] afterwards to continue. A [method play] in progress keeps
## waiting and returns when the restored story ends.
func restore(data: Dictionary) -> void:
	_halt()
	_playing = false
	_story_vars = JSON.to_native(data.get("vars", {}))
	_visited.clear()
	for key in data.get("visited", []):
		_visited[key] = true
	_once_chosen.clear()
	for key in data.get("once", []):
		_once_chosen[key] = true
	for saved in data.get("stack", []):
		var tale := get_tale(saved["tale"])
		if tale == null:
			_report("Can't restore: tale '%s' is missing." % saved["tale"], saved["tale"], 0)
			_stack.clear()
			return
		var frame := TaleFrame.new(tale, saved["beat"])
		frame.pc = int(saved["pc"])
		frame.locals = JSON.to_native(saved["locals"])
		frame.iterators = JSON.to_native(saved["iterators"])
		_stack.append(frame)


## Continues playback from a restored state. Awaitable: returns when the
## story ends.
func resume() -> void:
	if _stack.is_empty() or _playing:
		return
	_generation += 1
	var generation := _generation
	_playing = true
	await _run(generation)


## Data kept across playthroughs: global variables, read lines, and the
## routes explored. Saved separately from save slots.
func capture_globals() -> Dictionary:
	return {"vars": JSON.from_native(_global_vars), "read": _read_lines.keys(), "routes": routes.to_dict()}


func restore_globals(data: Dictionary) -> void:
	_global_vars = JSON.to_native(data.get("vars", {}))
	_read_lines.clear()
	for id in data.get("read", []):
		_read_lines[id] = true
	routes.from_dict(data.get("routes", {}))


## True if the player has seen the line with [param line_id] in any playthrough.
func is_line_read(line_id: String) -> bool:
	return _read_lines.has(line_id)


# --- Name resolution (used by TaleEvaluator) ------------------------------------

## Returns [found, value] for a name used in [param frame].
func resolve_name(name: String, frame: TaleFrame) -> Array:
	if frame != null:
		if frame.locals.has(name):
			return [true, frame.locals[name]]
		var found := get_tale_var(frame.tale.tale_name, name)
		if found[0]:
			return found
	if POSITIONS.has(name):
		return [true, POSITIONS[name]]
	match name:
		"PI":
			return [true, PI]
		"TAU":
			return [true, TAU]
		"INF":
			return [true, INF]
		"NAN":
			return [true, NAN]
	if _exposed.has(name) and _exposed[name] is TaleExposed:
		return [true, _exposed[name]]
	for crew in _name_providers():
		var provided: Array = crew.resolve_tale_name(name)
		if provided[0]:
			return provided
	if get_tale(name) != null:
		return [true, TaleNamespace.new(name)]
	return [false, null]


## Returns [found, value] for a story or global variable of a tale.
func get_tale_var(tale_name: String, var_name: String) -> Array:
	var vars: Dictionary = _story_vars.get(tale_name, {})
	if vars.has(var_name):
		return [true, vars[var_name]]
	var tale := get_tale(tale_name)
	if tale != null:
		for variable in tale.variables:
			if variable["name"] == var_name and variable["global"]:
				return [true, _global_vars.get(var_name)]
	return [false, null]


## Sets a story or global variable. Returns an error message or "".
func set_tale_var(tale_name: String, var_name: String, value: Variant) -> String:
	if _constants.get(tale_name, {}).has(var_name):
		return "Can't assign to the constant '%s'." % var_name
	var vars: Dictionary = _story_vars.get(tale_name, {})
	if vars.has(var_name):
		vars[var_name] = value
		return ""
	var tale := get_tale(tale_name)
	if tale != null:
		for variable in tale.variables:
			if variable["name"] == var_name and variable["global"]:
				_global_vars[var_name] = value
				return ""
	return "Tale '%s' has no variable '%s'." % [tale_name, var_name]


## Assigns a variable visible from [param frame]. Returns an error message or "".
func assign_name(name: String, value: Variant, frame: TaleFrame) -> String:
	if frame.locals.has(name):
		frame.locals[name] = value
		return ""
	return set_tale_var(frame.tale.tale_name, name, value)


## Calls an action, built-in function, constructor, or exposed function.
func call_function(name: String, args: Array, named: Dictionary, frame: TaleFrame) -> Variant:
	if frame != null and (frame.locals.has(name) or get_tale_var(frame.tale.tale_name, name)[0]):
		_evaluator.fail("'%s' is a variable and can't be called." % name)
		return null
	if frame != null and frame.tale.get_beat_start(name) >= 0:
		_evaluator.fail("Beats can only be called on a line of their own, e.g. %s()." % name)
		return null
	if _actions.has(name):
		return _call_action(_actions[name], args, named)
	if _exposed.has(name) and _exposed[name] is Callable:
		if not named.is_empty():
			_evaluator.fail("'%s' does not take named arguments." % name)
			return null
		return start_task(_exposed[name], args)
	if not named.is_empty():
		_evaluator.fail("'%s' does not take named arguments." % name)
		return null
	return _builtin_function(name, args)


## Starts [param callable] as a [TaleTask]. Returns its result when it
## finishes at once, or the task when it is still running.
func start_task(callable: Callable, args: Array) -> Variant:
	var task := TaleTask.new(callable, args)
	if task.is_done:
		return task.result
	_pending.append(task)
	return task


# --- Run loop -------------------------------------------------------------------

func _run(generation: int) -> void:
	var steps := 0
	while generation == _generation and not _stack.is_empty():
		var frame: TaleFrame = _stack.back()
		if frame.pc < 0 or frame.pc >= frame.tale.instructions.size():
			_stack.pop_back()
			continue
		var instruction: Dictionary = frame.tale.instructions[frame.pc]
		frame.pc += 1
		steps += 1
		if steps > max_steps_without_pause:
			_report("Stopped after %d steps without showing a line. Is there an endless loop?" % steps, frame.tale.tale_name, instruction["line"])
			break
		var op: String = instruction["op"]
		if op == "say" or op == "choose":
			steps = 0
		_current_tale = frame.tale.tale_name
		_current_line = instruction["line"]
		if instruction.get("no_rewind", false):
			rewind_barrier.emit()
		_evaluator.reset()
		await _execute(instruction, frame)
		if _evaluator.failed():
			_report(_evaluator.error, frame.tale.tale_name, instruction["line"])
	if generation == _generation and _playing:
		_playing = false
		story_finished.emit()


func _execute(instruction: Dictionary, frame: TaleFrame) -> void:
	match instruction["op"]:
		"say":
			await _say(instruction, frame)
		"eval":
			if not await _try_tale_beat_call(instruction["expr"], frame):
				await _evaluator.evaluate(instruction["expr"], frame)
		"set":
			var value: Variant = await _evaluator.evaluate(instruction["value"], frame)
			if not _evaluator.failed():
				await _evaluator.assign(instruction["place"], instruction["assign"], value, frame)
		"local":
			var initial: Variant = null
			if instruction["value"] != null:
				initial = await _evaluator.evaluate(instruction["value"], frame)
			frame.locals[instruction["name"]] = initial
		"jump":
			var target := _find_tale(instruction["tale"], frame)
			if target != null and _check_beat(target, instruction["beat"], instruction["line"]):
				await _prepare_tale(target)
				_stack[_stack.size() - 1] = _enter_beat(target, instruction["beat"])
		"call_beat":
			var callee := _find_tale(instruction["tale"], frame)
			if callee != null and _check_beat(callee, instruction["beat"], instruction["line"]):
				await _prepare_tale(callee)
				_stack.append(_enter_beat(callee, instruction["beat"]))
		"return", "end":
			_stack.pop_back()
		"goto":
			frame.pc = instruction["target"]
		"branch_false":
			var condition: Variant = await _evaluator.evaluate(instruction["cond"], frame)
			if not condition:
				frame.pc = instruction["target"]
		"iter_begin":
			var iterable: Variant = await _evaluator.evaluate(instruction["iterable"], frame)
			frame.iterators[instruction["slot"]] = {"items": _to_items(iterable), "index": 0}
		"iter_next":
			var state: Dictionary = frame.iterators.get(instruction["slot"], {"items": [], "index": 0})
			if state["index"] >= state["items"].size():
				frame.iterators.erase(instruction["slot"])
				frame.pc = instruction["target"]
			else:
				frame.locals[instruction["var"]] = state["items"][state["index"]]
				state["index"] += 1
		"match":
			await _match(instruction, frame)
		"choose":
			await _choose(instruction, frame)


func _say(instruction: Dictionary, frame: TaleFrame) -> void:
	var generation := _generation
	await _finish_pending()
	var acts: Array = []
	var text: String = await _render(_localize(instruction["text"], instruction["id"], frame.tale, instruction["line"]), frame, acts)
	text = TaleText.expand_styles(text, text_styles)
	var speaker: String = instruction["speaker"]
	var speaker_info := _speaker_info(speaker, frame)
	var line := {
		"speaker_id": speaker,
		"speaker_name": speaker_info[0],
		"speaker_color": speaker_info[1],
		"mood": instruction["mood"],
		"text": text,
		"id": instruction["id"],
		"voice": instruction["voice"],
		"tale": frame.tale.tale_name,
		"beat": frame.beat,
		"source_line": instruction["line"],
		"read": _read_lines.has(instruction["id"]) or instruction.get("skip_safe", false),
	}
	if generation != _generation:
		return
	_line_pc = frame.pc - 1
	_text_acts = acts
	_text_frame = frame
	line_started.emit(line)
	var target := _get_presenter()
	if target != null:
		await target.show_line(line)
	if generation == _generation:
		_text_acts = []
		_text_frame = null
		_read_lines[instruction["id"]] = true
		_line_pc = -1
		line_finished.emit(line)


func _match(instruction: Dictionary, frame: TaleFrame) -> void:
	var subject: Variant = await _evaluator.evaluate(instruction["subject"], frame)
	for branch in instruction["branches"]:
		var matched := false
		for pattern in branch["patterns"]:
			if pattern == null:
				matched = true
			else:
				matched = TaleEvaluator.values_equal(subject, await _evaluator.evaluate(pattern, frame))
			if matched:
				break
		if matched and branch["guard"] != null:
			matched = bool(await _evaluator.evaluate(branch["guard"], frame))
		if matched:
			frame.pc = branch["target"]
			return
	frame.pc = instruction["end"]


func _choose(instruction: Dictionary, frame: TaleFrame) -> void:
	var generation := _generation
	await _finish_pending()
	var settings := {}
	for key in instruction["args"]:
		settings[key] = await _evaluator.evaluate(instruction["args"][key], frame)
	var shown: Array[Dictionary] = []
	var sources: Array[Dictionary] = []
	for option in instruction["options"]:
		if option["once"] and _once_chosen.has(option["id"]):
			continue
		var enabled := true
		if option["cond"] != null:
			enabled = bool(await _evaluator.evaluate(option["cond"], frame))
		if not enabled and not option["show_disabled"]:
			continue
		var parts := _localize(option["text"], option["id"], frame.tale, option["line"])
		shown.append({"text": await _render(parts, frame), "id": option["id"], "enabled": enabled, "picture": option.get("picture", "")})
		sources.append(option)
		routes.see_option(frame.tale.translation_key(option["id"]))
	var has_enabled := shown.any(func(option: Dictionary) -> bool: return option["enabled"])
	if not has_enabled:
		frame.pc = instruction["timeout_target"] if instruction["timeout_target"] >= 0 else instruction["end"]
		return
	if generation != _generation:
		return
	_line_pc = frame.pc - 1
	choice_started.emit(shown)
	var target := _get_presenter()
	var picked := 0
	if target != null:
		picked = await target.choose(shown, settings)
	if generation != _generation:
		return
	_line_pc = -1
	if picked < 0 or picked >= shown.size() or not shown[picked]["enabled"]:
		frame.pc = instruction["timeout_target"] if instruction["timeout_target"] >= 0 else instruction["end"]
		return
	var option := sources[picked]
	if option["once"]:
		_once_chosen[option["id"]] = true
	routes.pick_option(frame.tale.translation_key(option["id"]))
	choice_made.emit(shown[picked])
	frame.pc = option["target"]


# --- Helpers --------------------------------------------------------------------

## Called while the frame the story comes from is still on top of the stack.
func _enter_beat(tale: Tale, beat: String) -> TaleFrame:
	var beat_id := "%s.%s" % [tale.tale_name, beat]
	_visited[beat_id] = true
	var from: TaleFrame = _stack.back() if not _stack.is_empty() else null
	routes.enter(beat_id, "%s.%s" % [from.tale.tale_name, from.beat] if from != null else "")
	beat_entered.emit(tale.tale_name, beat)
	_preload_beat(tale, tale.get_beat_start(beat))
	return TaleFrame.new(tale, beat)


## Asks crew members to start loading the assets a beat names, so they are
## ready when the beat reaches them.
func _preload_beat(tale: Tale, start: int) -> void:
	var loaders := _crew_siblings().filter(func(crew: Node) -> bool: return crew.has_method("preload_asset"))
	if loaders.is_empty() or start < 0:
		return
	for i in range(start, mini(start + PRELOAD_SCAN_LIMIT, tale.instructions.size())):
		var instruction: Dictionary = tale.instructions[i]
		var kind := ""
		var asset := ""
		match instruction["op"]:
			"end":
				break
			"say":
				if not instruction["voice"].is_empty():
					kind = "voice"
					asset = instruction["voice"]
			"eval":
				var expr: Array = instruction["expr"]
				if expr[0] == "call" and expr[1][0] == "name" and expr[1][1] in PRELOAD_ACTIONS:
					var args: Array = expr[2]
					if not args.is_empty() and args[0][0] == "lit" and args[0][1] is String:
						kind = expr[1][1]
						asset = args[0][1]
		if not asset.is_empty():
			for loader in loaders:
				loader.preload_asset(kind, asset)


## Initializes a tale's story and global variables the first time it runs.
## Instruction in [param new] that matches [param pc] in [param old], or -1
## when the beat no longer exists. Lines are matched by id. A line whose
## text was edited is found from the next unchanged line after it.
static func _map_pc(old: Tale, new: Tale, beat: String, pc: int) -> int:
	var start := new.get_beat_start(beat)
	if start < 0:
		return -1
	if pc < 0 or pc >= old.instructions.size():
		return start
	var before: Dictionary = old.instructions[pc]
	for i in new.instructions.size():
		var instruction: Dictionary = new.instructions[i]
		if before["op"] == "say" and instruction["op"] == "say" and instruction["id"] == before["id"]:
			return i
		if before["op"] == "choose" and instruction["op"] == "choose" and not before["options"].is_empty():
			for option in instruction["options"]:
				if option["id"] == before["options"][0]["id"]:
					return i
	if before["op"] == "say":
		var anchor := _next_shared_line(old, new, pc)
		if anchor >= 0:
			# The line just before the anchor is the edited one, unless it is
			# an old line too (then the current line was deleted).
			for i in range(anchor - 1, start - 1, -1):
				var instruction: Dictionary = new.instructions[i]
				if instruction["op"] == "say":
					return i if not old.texts.has(instruction["id"]) else anchor
			return anchor
	for i in range(start, new.instructions.size()):
		if new.instructions[i]["line"] >= before["line"] or new.instructions[i]["op"] == "end":
			return i
	return start


## Index in [param new] of the first line after [param pc] in [param old]
## that both versions share, within the same beat, or -1.
static func _next_shared_line(old: Tale, new: Tale, pc: int) -> int:
	for j in range(pc + 1, old.instructions.size()):
		var later: Dictionary = old.instructions[j]
		if later["op"] == "end":
			return -1
		if later["op"] != "say":
			continue
		for i in new.instructions.size():
			if new.instructions[i]["op"] == "say" and new.instructions[i]["id"] == later["id"]:
				return i
	return -1


## Gives variables added to a tale since it started their initial values.
func _add_new_variables(tale: Tale) -> void:
	var vars: Dictionary = _story_vars[tale.tale_name]
	var frame := TaleFrame.new(tale, "")
	for variable in tale.variables:
		if variable["global"] or variable["const"] or vars.has(variable["name"]):
			continue
		var evaluator := TaleEvaluator.new(self)
		vars[variable["name"]] = await evaluator.evaluate(variable["value"], frame) if variable["value"] != null else null


func _process(delta: float) -> void:
	if not live_reload:
		return
	_reload_timer += delta
	if _reload_timer < LIVE_RELOAD_INTERVAL:
		return
	_reload_timer = 0.0
	check_for_edits()


## Reloads every loaded tale whose source file changed. Called once a
## second while [member live_reload] is on.
func check_for_edits() -> void:
	for tale_name in _tales.keys():
		var path: String = _tales[tale_name].source_path
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var time := FileAccess.get_modified_time(path)
		if not _source_times.has(path):
			_source_times[path] = time
		elif _source_times[path] != time:
			var problem: String = await reload_tale(tale_name)
			if not problem.is_empty():
				push_warning("StoryTeller: live reload: " + problem)
				reload_failed.emit(tale_name, problem)


func _prepare_tale(tale: Tale) -> void:
	if _story_vars.has(tale.tale_name):
		return
	_story_vars[tale.tale_name] = {}
	_constants[tale.tale_name] = {}
	var frame := TaleFrame.new(tale, "")
	for variable in tale.variables:
		var value: Variant = null
		if variable["value"] != null:
			_evaluator.reset()
			value = await _evaluator.evaluate(variable["value"], frame)
			if _evaluator.failed():
				_report(_evaluator.error, tale.tale_name, variable["line"])
		if variable["global"]:
			if not _global_vars.has(variable["name"]):
				_global_vars[variable["name"]] = value
		else:
			_story_vars[tale.tale_name][variable["name"]] = value
			if variable["const"]:
				_constants[tale.tale_name][variable["name"]] = true


func _find_tale(tale_name: String, frame: TaleFrame) -> Tale:
	if tale_name.is_empty():
		return frame.tale
	var tale := get_tale(tale_name)
	if tale == null:
		_evaluator.fail("Tale '%s' was not found." % tale_name)
	return tale


func _check_beat(tale: Tale, beat: String, line: int) -> bool:
	if tale.get_beat_start(beat) >= 0:
		return true
	_evaluator.fail("Tale '%s' has no beat '%s'." % [tale.tale_name, beat])
	return false


## Handles "other_tale.beat()" lines that the compiler could not resolve
## because it did not know the other tale. Returns true when handled.
func _try_tale_beat_call(expr: Array, frame: TaleFrame) -> bool:
	if expr[0] != "call" or expr[1][0] != "attr" or expr[1][1][0] != "name":
		return false
	if not (expr[2] as Array).is_empty() or not (expr[3] as Dictionary).is_empty():
		return false
	var tale_name: String = expr[1][1][1]
	if frame.locals.has(tale_name) or get_tale_var(frame.tale.tale_name, tale_name)[0] or _exposed.has(tale_name):
		return false
	var tale := get_tale(tale_name)
	if tale == null or tale.get_beat_start(expr[1][2]) < 0:
		return false
	await _prepare_tale(tale)
	_stack.append(_enter_beat(tale, expr[1][2]))
	return true


func _call_action(action: TaleAction, args: Array, named: Dictionary) -> Variant:
	var bound := TaleCalls.bind(action, "run", args, named, 1, action.get_action_name())
	if bound["error"]:
		_evaluator.fail(bound["error"])
		return null
	var call_args: Array = [_context]
	call_args.append_array(bound["values"])
	return start_task(Callable(action, "run"), call_args)


func _builtin_function(name: String, args: Array) -> Variant:
	var count := args.size()
	match name:
		"abs":
			if count == 1:
				return abs(args[0])
		"ceil":
			if count == 1:
				return ceil(args[0])
		"floor":
			if count == 1:
				return floor(args[0])
		"round":
			if count == 1:
				return round(args[0])
		"clamp":
			if count == 3:
				return clamp(args[0], args[1], args[2])
		"min", "max":
			if count >= 1:
				var best: Variant = args[0]
				for value in args:
					if (name == "min" and value < best) or (name == "max" and value > best):
						best = value
				return best
		"randf":
			if count == 0:
				return randf()
		"randi":
			if count == 0:
				return randi()
		"randf_range":
			if count == 2:
				return randf_range(args[0], args[1])
		"randi_range":
			if count == 2:
				return randi_range(args[0], args[1])
		"len":
			if count == 1 and (args[0] is String or args[0] is Array or args[0] is Dictionary):
				return args[0].length() if args[0] is String else args[0].size()
		"str":
			var text := ""
			for value in args:
				text += str(value)
			return text
		"int":
			if count == 1:
				return args[0].to_int() if args[0] is String else int(args[0])
		"float":
			if count == 1:
				return args[0].to_float() if args[0] is String else float(args[0])
		"tr":
			if count == 1:
				return tr(str(args[0]))
		"visited":
			if count == 1:
				return _visited.has(str(args[0]))
		"collected":
			if count == 1:
				var collection: Node = _sibling(&"Collection")
				return collection != null and collection.is_collected(str(args[0]))
		"Vector2", "Vector2i", "Vector3", "Color", "Rect2":
			return _construct(name, args)
		_:
			_evaluator.fail("Unknown function '%s'." % name)
			return null
	_evaluator.fail("Wrong arguments for '%s'." % name)
	return null


func _construct(type_name: String, args: Array) -> Variant:
	var names := PackedStringArray()
	for i in args.size():
		names.append("a%d" % i)
	var expression := Expression.new()
	if expression.parse("%s(%s)" % [type_name, ", ".join(names)], names) == OK:
		var value: Variant = expression.execute(args, null, false)
		if not expression.has_execute_failed():
			return value
	_evaluator.fail("Wrong arguments for %s()." % type_name)
	return null


## Builds the text of a line. [code][act][/code] and [code][sound][/code]
## tags become [code][act=N][/code] and [code][sound=N][/code], where N
## indexes the expression added to [param acts]; without [param acts]
## (choice options) they are left out.
func _render(parts: Array, frame: TaleFrame, acts: Variant = null) -> String:
	var text := ""
	for part in parts:
		if part is String:
			text += part
		elif part is Dictionary:
			if acts is Array:
				text += "[%s=%d]" % [part["tag"], acts.size()]
				acts.append(part["expr"])
		else:
			text += str(await _evaluator.evaluate(part, frame))
	return text


## Returns the text parts of a line or option in the current language: the
## translation keyed [code]<tale>:<id>[/code] when there is one, compiled on
## first use, or [param parts] otherwise.
func _localize(parts: Array, id: String, tale: Tale, line: int) -> Array:
	if is_source_language():
		return parts
	var key := tale.translation_key(id)
	var translated := String(TranslationServer.translate(key))
	if translated == key or translated.is_empty():
		return parts
	if not _translated.has(translated):
		var compiled := TaleCompiler.compile_text(translated)
		if compiled["errors"].is_empty():
			_translated[translated] = compiled["parts"]
		else:
			_report("The %s translation of this line has a problem: %s" % [TranslationServer.get_locale(), compiled["errors"][0]], tale.tale_name, line)
			_translated[translated] = parts
	return _translated[translated]


## True while the game's locale is the language the tales are written in.
func is_source_language() -> bool:
	return TranslationServer.get_locale().get_slice("_", 0) == source_language.get_slice("_", 0)


## Returns [display name, name color] for a speaker id. Names are
## translated, keyed by their text.
func _speaker_info(speaker: String, frame: TaleFrame) -> Array:
	if speaker.is_empty():
		return ["", Color.WHITE]
	var found := resolve_name(speaker, frame)
	if found[0] and found[1] is String:
		return [_translate(found[1]), Color.WHITE]
	if found[0] and found[1] is Object and found[1].has_method("get_display_name"):
		return [_translate(found[1].get_display_name()), found[1].get_name_color()]
	return [_translate(speaker.capitalize()), Color.WHITE]


static func _translate(text: String) -> String:
	return String(TranslationServer.translate(text)) if not text.is_empty() else text


## The crew member called [param crew_name] in the same Story, or null.
func _sibling(crew_name: StringName) -> Node:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(crew_name)
	return null


## Other crew members of the Story this director belongs to.
func _crew_siblings() -> Array:
	var story := get_parent()
	if story == null or not story.has_method("get_crew_names"):
		return []
	var result := []
	for crew_name in story.get_crew_names():
		var crew: Node = story.get_crew(crew_name)
		if crew != self:
			result.append(crew)
	return result


## Crew members that supply names to tales (cast members, the camera).
func _name_providers() -> Array:
	return _crew_siblings().filter(func(crew: Node) -> bool: return crew.has_method("resolve_tale_name"))


func _to_items(value: Variant) -> Array:
	if value is Array:
		return value.duplicate()
	if value is Dictionary:
		return value.keys()
	if value is String:
		var characters: Array = []
		for character in value:
			characters.append(character)
		return characters
	if value is int:
		return range(value)
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return Array(value)
	_evaluator.fail("Can't loop over %s." % type_string(typeof(value)))
	return []


func _finish_pending() -> void:
	for task in _pending:
		if not task.is_done:
			await task.finished
	_pending.clear()


func _get_presenter() -> Object:
	if presenter != null:
		return presenter
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(&"Dialogue")
	return null


## Reports a runtime problem for the instruction being run.
func report_error(message: String) -> void:
	_report(message, _current_tale, _current_line)


func _report(message: String, tale_name: String, line: int) -> void:
	push_error("StoryTeller: %s:%d: %s" % [tale_name, line, message])
	runtime_error.emit(message, tale_name, line)

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
## Emitted after the player picks an option.
signal choice_made(option: Dictionary)
## Emitted by [code]emit("name", value)[/code] in tales.
signal story_signal(signal_name: String, value: Variant)
## Emitted when a tale does something invalid at runtime. The director
## reports it and continues with the next instruction.
signal runtime_error(message: String, tale_name: String, line: int)

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
	preload("res://addons/storyteller/actions/action_shake.gd"),
	preload("res://addons/storyteller/actions/action_music.gd"),
	preload("res://addons/storyteller/actions/action_stop_music.gd"),
	preload("res://addons/storyteller/actions/action_sound.gd"),
	preload("res://addons/storyteller/actions/action_ambience.gd"),
	preload("res://addons/storyteller/actions/action_stop_ambience.gd"),
	preload("res://addons/storyteller/actions/action_voice.gd"),
	preload("res://addons/storyteller/actions/action_stop_audio.gd"),
]
## Actions whose first argument names an asset that can be loaded ahead.
const PRELOAD_ACTIONS := ["backdrop", "prop", "music", "sound", "ambience", "voice"]
## How many instructions of a beat are scanned for assets to preload.
const PRELOAD_SCAN_LIMIT := 400

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
	tales_folder = config.tales_folder


func clear() -> void:
	stop()
	_story_vars.clear()
	_constants.clear()
	_visited.clear()
	_once_chosen.clear()


# --- Public API -------------------------------------------------------------

## Plays [param tale_name] from [param beat]. Awaitable: returns when the
## story finishes or is stopped.
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
	await _run(generation)


## Stops playback. A [method play] in progress returns.
func stop() -> void:
	_generation += 1
	if _playing:
		_playing = false
		story_finished.emit()
	_stack.clear()
	_pending.clear()


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
	for crew in _crew_siblings():
		if crew.has_method("get_tale_names"):
			for extra in crew.get_tale_names():
				context.add_exposed(extra)
		if crew.has_method("get_cast_moods"):
			var cast: Dictionary = crew.get_cast_moods()
			for id in cast:
				context.add_cast(id, cast[id])
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
	for frame in _stack:
		frames.append({
			"tale": frame.tale.tale_name,
			"beat": frame.beat,
			"pc": frame.pc,
			"locals": JSON.from_native(frame.locals),
			"iterators": JSON.from_native(frame.iterators),
		})
	return {
		"stack": frames,
		"vars": JSON.from_native(_story_vars),
		"visited": _visited.keys(),
		"once": _once_chosen.keys(),
	}


func restore(data: Dictionary) -> void:
	stop()
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


## Continues playback from a restored state. Awaitable.
func resume() -> void:
	if _stack.is_empty() or _playing:
		return
	_generation += 1
	var generation := _generation
	_playing = true
	await _run(generation)


## Global variables, saved separately from save slots.
func capture_globals() -> Dictionary:
	return JSON.from_native(_global_vars)


func restore_globals(data: Dictionary) -> void:
	_global_vars = JSON.to_native(data)


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
	await _finish_pending()
	var text: String = await _render(instruction["text"], frame)
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
	}
	line_started.emit(line)
	var target := _get_presenter()
	if target != null:
		await target.show_line(line)


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
		shown.append({"text": await _render(option["text"], frame), "id": option["id"], "enabled": enabled})
		sources.append(option)
	var has_enabled := shown.any(func(option: Dictionary) -> bool: return option["enabled"])
	if not has_enabled:
		frame.pc = instruction["timeout_target"] if instruction["timeout_target"] >= 0 else instruction["end"]
		return
	var target := _get_presenter()
	var picked := 0
	if target != null:
		picked = await target.choose(shown, settings)
	if picked < 0 or picked >= shown.size() or not shown[picked]["enabled"]:
		frame.pc = instruction["timeout_target"] if instruction["timeout_target"] >= 0 else instruction["end"]
		return
	var option := sources[picked]
	if option["once"]:
		_once_chosen[option["id"]] = true
	choice_made.emit(shown[picked])
	frame.pc = option["target"]


# --- Helpers --------------------------------------------------------------------

func _enter_beat(tale: Tale, beat: String) -> TaleFrame:
	_visited["%s.%s" % [tale.tale_name, beat]] = true
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
				return false
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


func _render(parts: Array, frame: TaleFrame) -> String:
	var text := ""
	for part in parts:
		if part is String:
			text += part
		else:
			text += str(await _evaluator.evaluate(part, frame))
	return text


## Returns [display name, name color] for a speaker id.
func _speaker_info(speaker: String, frame: TaleFrame) -> Array:
	if speaker.is_empty():
		return ["", Color.WHITE]
	var found := resolve_name(speaker, frame)
	if found[0] and found[1] is String:
		return [found[1], Color.WHITE]
	if found[0] and found[1] is Object and found[1].has_method("get_display_name"):
		return [found[1].get_display_name(), found[1].get_name_color()]
	return [speaker.capitalize(), Color.WHITE]


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

class_name StoryConsole
extends StoryCrew
## Debug console for writers and testers, in debug builds only. Press F3 or
## the key left of 1 (` on US keyboards) to open it. It shows where the
## story is and its variables, lists errors as they happen, and runs
## commands:
## [codeblock]
## jump prologue.start     # go to a beat (or just "jump start")
## trust = 3               # set a variable
## trust * 2               # show the value of an expression
## reload                  # reload edited tales now
## unlock_all              # unlock every collection item
## [/codeblock]

## Emitted with each line written to the console log.
signal printed(text: String)

const LAYER := 50
const KEYS := [KEY_F3, KEY_QUOTELEFT]
const HELP := """Commands:
  jump <tale>.<beat>   go to a beat (or jump <beat> in this tale)
  <name> = <expr>      set a variable
  <expr>               show a value, e.g. trust + 1
  reload               reload tales whose files changed
  unlock_all           unlock every collection item
  clear                clear this log
  help                 show this list"""

## False turns the console off even in debug builds.
var enabled := OS.is_debug_build()

var _layer: CanvasLayer
var _panel: PanelContainer
var _status: Label
var _log: RichTextLabel
var _vars: RichTextLabel
var _input: LineEdit
var _history: PackedStringArray = []
var _history_index := 0


func get_crew_name() -> StringName:
	return &"Console"


func setup(_config: StoryConfig) -> void:
	if not enabled:
		return
	if not InputMap.has_action("story_console"):
		InputMap.add_action("story_console")
		for key in KEYS:
			var event := InputEventKey.new()
			event.keycode = key
			InputMap.action_add_event("story_console", event)
	_connect_director.call_deferred()


func is_open() -> bool:
	return _panel != null and _panel.visible


func toggle() -> void:
	if _panel == null:
		_build()
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()
		_input.grab_focus()


## Writes a line to the console log.
func write(text: String) -> void:
	if _log != null:
		_log.append_text(text.replace("[", "[lb]") + "\n")
	printed.emit(text)


## Runs one console command. Awaitable.
func run_command(command: String) -> void:
	command = command.strip_edges()
	if command.is_empty():
		return
	write("> " + command)
	var director := _director()
	if director == null:
		write("There is no TaleDirector.")
		return
	var words := command.split(" ", false)
	match words[0]:
		"help":
			write(HELP)
			return
		"clear":
			if _log != null:
				_log.clear()
			return
		"reload":
			await director.check_for_edits()
			write("Checked for edited tales.")
			return
		"unlock_all":
			var collection := _crew(&"Collection") as StoryCollection
			if collection == null:
				write("There is no Collection crew member.")
			else:
				collection.unlock_all()
				write("Unlocked every collection item.")
			return
		"jump":
			if words.size() != 2:
				write("Usage: jump <tale>.<beat> or jump <beat>")
				return
			var target := words[1]
			var tale_name: String = target.get_slice(".", 0) if "." in target else str(director.get_position().get("tale", ""))
			var beat := target.get_slice(".", 1) if "." in target else target
			var problem: String = await director.jump_to(tale_name, beat)
			write(problem if not problem.is_empty() else "Jumped to %s.%s." % [tale_name, beat])
			return
	var assignment := RegEx.create_from_string("^([A-Za-z_][A-Za-z0-9_]*)\\s*=(?!=)\\s*(.+)$").search(command)
	if assignment != null:
		var var_name := assignment.get_string(1)
		var evaluated: Array = await director.evaluate_source(assignment.get_string(2))
		if not evaluated[0]:
			write(str(evaluated[1]))
			return
		var position := director.get_position()
		var problem := director.set_tale_var(position.get("tale", ""), var_name, evaluated[1]) if not position.is_empty() else "Nothing is playing."
		write(problem if not problem.is_empty() else "%s = %s" % [var_name, _format(evaluated[1])])
		_refresh()
		return
	var result: Array = await director.evaluate_source(command)
	write(_format(result[1]) if result[0] else str(result[1]))


func _process(_delta: float) -> void:
	if is_open():
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed("story_console") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ConsoleLayer"
	_layer.layer = LAYER
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.name = "Console"
	_panel.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.anchor_bottom = 0.45
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.04, 0.06, 0.92)
	background.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", background)
	_panel.visible = false
	_layer.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	column.add_child(_status)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.selection_enabled = true
	split.add_child(_log)
	_vars = RichTextLabel.new()
	_vars.custom_minimum_size = Vector2(300, 0)
	split.add_child(_vars)
	_input = LineEdit.new()
	_input.placeholder_text = "Type a command, or help"
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_key)
	column.add_child(_input)
	write("StoryTeller console. Type help for commands.")


func _on_submitted(text: String) -> void:
	_input.clear()
	if not text.strip_edges().is_empty():
		_history.append(text)
		_history_index = _history.size()
	await run_command(text)


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or _history.is_empty():
		return
	if event.keycode == KEY_UP:
		_history_index = maxi(_history_index - 1, 0)
	elif event.keycode == KEY_DOWN:
		_history_index = mini(_history_index + 1, _history.size())
	elif event.is_action("story_console"):
		toggle()
		_input.accept_event()
		return
	else:
		return
	_input.text = _history[_history_index] if _history_index < _history.size() else ""
	_input.caret_column = _input.text.length()
	_input.accept_event()


func _refresh() -> void:
	var director := _director()
	if director == null or _status == null:
		return
	var position := director.get_position()
	if position.is_empty():
		_status.text = "Not playing"
	else:
		_status.text = "%s.%s, line %d%s" % [position["tale"], position["beat"], position["line"], "  (skipping)" if director.skipping else ""]
	var text := ""
	var vars := director.get_variables()
	var names := vars.keys()
	names.sort()
	for var_name in names:
		text += "%s = %s\n" % [var_name, _format(vars[var_name])]
	_vars.text = text


func _connect_director() -> void:
	var director := _director()
	if director == null:
		return
	director.runtime_error.connect(func(message: String, tale_name: String, line: int) -> void:
		write("Error in %s:%d: %s" % [tale_name, line, message]))
	director.tale_reloaded.connect(func(tale_name: String) -> void: write("Reloaded %s." % tale_name))
	director.reload_failed.connect(func(_tale_name: String, message: String) -> void: write("Not reloaded: " + message))


static func _format(value: Variant) -> String:
	return JSON.stringify(value) if value is String else var_to_str(value) if value is Object else str(value)


func _director() -> TaleDirector:
	return _crew(&"TaleDirector") as TaleDirector


func _crew(crew_name: StringName) -> Node:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(crew_name)
	return null

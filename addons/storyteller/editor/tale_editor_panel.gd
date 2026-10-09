@tool
class_name TaleEditorPanel
extends Control
## The "Story" main screen: a list of the project's tales, a TaleScript
## editor with syntax highlighting and autocomplete, the card editor (a
## visual view of the same text), the Story Map of the tale's folder, and a
## live list of problems.
##
## Edits are kept per file until saved, so switching files loses nothing.
## Ctrl+S (Cmd+S on macOS) saves the open tale and reimports it.

## Emitted after a tale is saved.
signal tale_saved(path: String)

const CHECK_DELAY := 0.4
const ERROR_LINE_COLOR := Color(1.0, 0.3, 0.3, 0.15)
const WARNING_LINE_COLOR := Color(1.0, 0.8, 0.2, 0.12)
const COMPLETION_KINDS := {
	TaleCompletion.Kind.KEYWORD: CodeEdit.KIND_PLAIN_TEXT,
	TaleCompletion.Kind.ACTION: CodeEdit.KIND_FUNCTION,
	TaleCompletion.Kind.CAST: CodeEdit.KIND_CLASS,
	TaleCompletion.Kind.MOOD: CodeEdit.KIND_ENUM,
	TaleCompletion.Kind.BEAT: CodeEdit.KIND_SIGNAL,
	TaleCompletion.Kind.TALE: CodeEdit.KIND_FILE_PATH,
	TaleCompletion.Kind.VARIABLE: CodeEdit.KIND_VARIABLE,
	TaleCompletion.Kind.FUNCTION: CodeEdit.KIND_FUNCTION,
	TaleCompletion.Kind.CONSTANT: CodeEdit.KIND_CONSTANT,
	TaleCompletion.Kind.MEMBER: CodeEdit.KIND_MEMBER,
	TaleCompletion.Kind.ANNOTATION: CodeEdit.KIND_PLAIN_TEXT,
}

var file_list: ItemList
var code_edit: CodeEdit
var problem_list: ItemList
var highlighter: TaleSyntaxHighlighter
var card_editor: TaleCardEditor
var story_map: StoryMapView
## "text", "cards", or "map".
var view := "text"

var _title: Label
var _view_buttons: Dictionary = {}
var _save_button: Button
var _check_timer: Timer
var _current_path := ""
## Path -> {"text": String, "saved": String} for every opened file.
var _buffers: Dictionary = {}
var _loading := false
var _diagnostics: Array[TaleDiagnostic] = []
## Check context from the last check, reused for autocomplete.
var _context: TaleCheckContext


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	refresh_files()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	_title = Label.new()
	_title.text = "No tale open"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_title)
	var refresh := Button.new()
	refresh.text = "Refresh List"
	refresh.pressed.connect(refresh_files)
	toolbar.add_child(refresh)
	var export := Button.new()
	export.text = "Export Strings"
	export.tooltip_text = "Write every line, choice, name, and menu text to the translation CSV set in StoryConfig."
	export.pressed.connect(export_strings)
	toolbar.add_child(export)
	var views := ButtonGroup.new()
	for view_name in ["Text", "Cards", "Map"]:
		var button := Button.new()
		button.text = view_name
		button.toggle_mode = true
		button.button_group = views
		button.button_pressed = view_name == "Text"
		button.name = view_name + "View"
		button.pressed.connect(show_view.bind(view_name.to_lower()))
		toolbar.add_child(button)
		_view_buttons[view_name.to_lower()] = button
	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.disabled = true
	_save_button.pressed.connect(save_current)
	toolbar.add_child(_save_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 220
	root.add_child(split)

	file_list = ItemList.new()
	file_list.custom_minimum_size = Vector2(180, 0)
	file_list.item_selected.connect(func(index: int) -> void: open_file(file_list.get_item_metadata(index)))
	split.add_child(file_list)

	var right := VSplitContainer.new()
	right.split_offset = -140
	split.add_child(right)

	code_edit = CodeEdit.new()
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_edit.gutters_draw_line_numbers = true
	code_edit.line_folding = true
	code_edit.gutters_draw_fold_gutter = true
	code_edit.indent_automatic = true
	code_edit.indent_use_spaces = false
	code_edit.indent_automatic_prefixes = [":"]
	code_edit.auto_brace_completion_enabled = true
	code_edit.auto_brace_completion_highlight_matching = true
	code_edit.add_comment_delimiter("#", "", true)
	code_edit.add_string_delimiter("\"", "\"", false)
	code_edit.add_string_delimiter("'", "'", false)
	code_edit.editable = false
	highlighter = TaleSyntaxHighlighter.new()
	highlighter.use_editor_theme()
	code_edit.syntax_highlighter = highlighter
	code_edit.code_completion_enabled = true
	code_edit.code_completion_prefixes = [".", "@", "(", "\""]
	code_edit.code_completion_requested.connect(_on_completion_requested)
	code_edit.text_changed.connect(_on_text_changed)
	code_edit.gui_input.connect(_on_code_input)
	if Engine.is_editor_hint():
		var editor_font := EditorInterface.get_editor_theme().get_font("source", "EditorFonts")
		if editor_font:
			code_edit.add_theme_font_override("font", editor_font)
	right.add_child(code_edit)
	card_editor = TaleCardEditor.new()
	card_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_editor.visible = false
	card_editor.source_changed.connect(apply_edit)
	card_editor.undo_requested.connect(func() -> void:
		code_edit.undo()
		_refresh_cards())
	card_editor.redo_requested.connect(func() -> void:
		code_edit.redo()
		_refresh_cards())
	right.add_child(card_editor)
	story_map = StoryMapView.new()
	story_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_map.visible = false
	story_map.beat_opened.connect(func(path: String, beat: String) -> void:
		open_file(path)
		show_view("cards")
		card_editor.select_beat(beat))
	story_map.edit_requested.connect(func(path: String, new_source: String) -> void:
		open_file(path)
		apply_edit(new_source)
		refresh_map())
	right.add_child(story_map)

	problem_list = ItemList.new()
	problem_list.custom_minimum_size = Vector2(0, 80)
	problem_list.item_activated.connect(_go_to_problem)
	problem_list.item_selected.connect(_go_to_problem)
	right.add_child(problem_list)

	_check_timer = Timer.new()
	_check_timer.one_shot = true
	_check_timer.wait_time = CHECK_DELAY
	_check_timer.timeout.connect(check_now)
	add_child(_check_timer)


## Switches between the "text" and "cards" views of the open tale.
func show_view(view_name: String) -> void:
	view = view_name
	if _view_buttons.has(view):
		_view_buttons[view].set_pressed_no_signal(true)
	code_edit.visible = view == "text"
	card_editor.visible = view == "cards"
	story_map.visible = view == "map"
	if view == "cards":
		_refresh_cards()
	elif view == "map":
		refresh_map()


## Redraws the Story Map from the tales in the open tale's folder, using
## unsaved edits where there are any.
func refresh_map() -> void:
	if _current_path.is_empty():
		return
	var folder := _current_path.get_base_dir()
	var tale_sources := {}
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".tale"):
			var path := folder.path_join(file_name)
			tale_sources[path] = _buffers[path]["text"] if _buffers.has(path) else FileAccess.get_file_as_string(path)
	if _buffers.has(_current_path):
		tale_sources[_current_path] = code_edit.text
	var config: StoryConfig = preload("res://addons/storyteller/core/story.gd").load_config()
	var start_tale := config.start_tale if config.tales_folder.trim_suffix("/") == folder else ""
	story_map.show_story(tale_sources, start_tale, config.start_beat)


## Applies [param new_source] from the card editor to the text as one
## undoable change that replaces only the lines that differ.
func apply_edit(new_source: String) -> void:
	var old := code_edit.text
	if new_source == old:
		return
	var a := old.split("\n")
	var b := new_source.split("\n")
	var start := 0
	while start < a.size() and start < b.size() and a[start] == b[start]:
		start += 1
	var end_a := a.size() - 1
	var end_b := b.size() - 1
	while end_a >= start and end_b >= start and a[end_a] == b[end_b]:
		end_a -= 1
		end_b -= 1
	code_edit.begin_complex_operation()
	if start >= a.size():
		code_edit.insert_text("\n" + "\n".join(b.slice(start, end_b + 1)), a.size() - 1, a[a.size() - 1].length())
	elif end_a >= start and end_b >= start:
		code_edit.remove_text(start, 0, end_a, a[end_a].length())
		code_edit.insert_text("\n".join(b.slice(start, end_b + 1)), start, 0)
	elif end_b >= start:
		code_edit.insert_text("\n".join(b.slice(start, end_b + 1)) + "\n", start, 0)
	elif start > 0:
		code_edit.remove_text(start - 1, a[start - 1].length(), end_a, a[end_a].length())
	else:
		code_edit.remove_text(0, 0, end_a + 1, 0)
	code_edit.end_complex_operation()
	if code_edit.text != new_source:
		code_edit.text = new_source
	# text_changed arrives a frame later; keep the buffer current now.
	_on_text_changed()
	_refresh_cards()


func _refresh_cards() -> void:
	if view != "cards" or _current_path.is_empty():
		return
	if _context == null:
		_context = _make_context()
	card_editor.set_source(code_edit.text, _context, _diagnostics)


## Lists every .tale file in the project, skipping folders with .gdignore.
func refresh_files() -> void:
	file_list.clear()
	for path in list_tale_files("res://"):
		var index := file_list.add_item(_list_label(path))
		file_list.set_item_metadata(index, path)
		file_list.set_item_tooltip(index, path)
		if path == _current_path:
			file_list.select(index)


## Opens [param path] in the editor, keeping unsaved edits of the
## previously open file in memory.
func open_file(path: String) -> void:
	if path == _current_path:
		return
	if not _buffers.has(path):
		var text := FileAccess.get_file_as_string(path)
		_buffers[path] = {"text": text, "saved": text}
	_current_path = path
	_context = null
	card_editor.current_beat = ""
	_loading = true
	code_edit.text = _buffers[path]["text"]
	code_edit.clear_undo_history()
	code_edit.editable = true
	_loading = false
	_update_title()
	for i in file_list.item_count:
		if file_list.get_item_metadata(i) == path:
			file_list.select(i)
	check_now()
	_refresh_cards()


## Writes the translation CSV (see [StoryStrings]) and reports the result.
func export_strings() -> void:
	var config: StoryConfig = preload("res://addons/storyteller/core/story.gd").load_config()
	var result := StoryStrings.export_strings(config)
	var message := "Exported %d strings to %s." % [result["count"], config.translation_file]
	for problem in result["problems"]:
		push_warning("StoryTeller: " + problem)
	if not result["problems"].is_empty():
		message += " %d problem(s); see the Output panel." % result["problems"].size()
	print("StoryTeller: " + message)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.get_editor_toaster().push_toast(message)


## Writes the open tale to disk and reimports it.
func save_current() -> void:
	if _current_path.is_empty():
		return
	var file := FileAccess.open(_current_path, FileAccess.WRITE)
	if file == null:
		push_error("StoryTeller: can't save %s." % _current_path)
		return
	file.store_string(code_edit.text)
	file.close()
	_buffers[_current_path]["saved"] = code_edit.text
	_update_title()
	if Engine.is_editor_hint():
		var filesystem := EditorInterface.get_resource_filesystem()
		filesystem.update_file(_current_path)
		filesystem.reimport_files(PackedStringArray([_current_path]))
	tale_saved.emit(_current_path)


func is_dirty(path: String) -> bool:
	return _buffers.has(path) and _buffers[path]["text"] != _buffers[path]["saved"]


func get_current_path() -> String:
	return _current_path


## Parses and checks the open text now and shows the problems.
func check_now() -> void:
	_diagnostics.clear()
	if _current_path.is_empty():
		_show_problems()
		return
	var tale_name := _current_path.get_file().get_basename()
	var doc := TaleParser.parse(code_edit.text, _current_path)
	_diagnostics.append_array(doc.diagnostics)
	if not doc.has_errors():
		_context = _make_context()
		_diagnostics.append_array(TaleChecker.check(doc, _context))
	_show_problems()
	if view == "cards" and card_editor.source == code_edit.text:
		card_editor.diagnostics = _diagnostics
		card_editor.rebuild()


func get_diagnostics() -> Array[TaleDiagnostic]:
	return _diagnostics


## Every .tale file under [param root], sorted.
static func list_tale_files(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	_collect_tales(root, found)
	found.sort()
	return found


static func _collect_tales(folder: String, found: PackedStringArray) -> void:
	if FileAccess.file_exists(folder.path_join(".gdignore")):
		return
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".tale"):
			found.append(folder.path_join(file_name))
	for sub in DirAccess.get_directories_at(folder):
		if not sub.begins_with("."):
			_collect_tales(folder.path_join(sub), found)


func _on_text_changed() -> void:
	if _loading or _current_path.is_empty():
		return
	_buffers[_current_path]["text"] = code_edit.text
	_update_title()
	if _check_timer.is_inside_tree():
		_check_timer.start()
	# Offer completions while a word is being typed.
	var column := code_edit.get_caret_column()
	var line := code_edit.get_line(code_edit.get_caret_line())
	if code_edit.has_focus() and column > 0 and column <= line.length() and (line[column - 1] == "_" or line[column - 1].is_valid_identifier()):
		code_edit.request_code_completion()


## Fills the autocomplete popup from [TaleCompletion].
func show_completions() -> void:
	if _current_path.is_empty():
		return
	if _context == null:
		_context = _make_context()
	var suggestions := TaleCompletion.suggest(code_edit.text, code_edit.get_caret_line(), code_edit.get_caret_column(), _context)
	for item in suggestions:
		code_edit.add_code_completion_option(COMPLETION_KINDS[item["kind"]], item["text"], item["insert"])
	code_edit.update_code_completion_options(false)


func _on_completion_requested() -> void:
	show_completions()


func _make_context() -> TaleCheckContext:
	var tale_name := _current_path.get_file().get_basename()
	return preload("res://addons/storyteller/editor/tale_importer.gd")._make_context(_current_path, tale_name)


func _on_code_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S \
			and (event.ctrl_pressed or event.meta_pressed):
		save_current()
		code_edit.accept_event()


func _show_problems() -> void:
	problem_list.clear()
	for line in code_edit.get_line_count():
		code_edit.set_line_background_color(line, Color(0, 0, 0, 0))
	for diagnostic in _diagnostics:
		var label := "Line %d: %s" % [diagnostic.line, diagnostic.message]
		var index := problem_list.add_item(("Error  " if diagnostic.is_error() else "Warning  ") + label)
		problem_list.set_item_metadata(index, diagnostic.line)
		var line := diagnostic.line - 1
		if line >= 0 and line < code_edit.get_line_count():
			code_edit.set_line_background_color(line, ERROR_LINE_COLOR if diagnostic.is_error() else WARNING_LINE_COLOR)
	if _diagnostics.is_empty() and not _current_path.is_empty():
		problem_list.add_item("No problems found.")
		problem_list.set_item_disabled(0, true)


func _go_to_problem(index: int) -> void:
	var line: Variant = problem_list.get_item_metadata(index)
	if line is int:
		code_edit.set_caret_line(line - 1)
		code_edit.center_viewport_to_caret()
		code_edit.grab_focus()


func _update_title() -> void:
	var dirty := is_dirty(_current_path)
	_title.text = _current_path + (" (unsaved)" if dirty else "")
	_save_button.disabled = not dirty
	for i in file_list.item_count:
		var path: String = file_list.get_item_metadata(i)
		file_list.set_item_text(i, _list_label(path))


func _list_label(path: String) -> String:
	return path.get_file() + (" *" if is_dirty(path) else "")

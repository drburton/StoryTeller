@tool
class_name TaleCardEditor
extends HSplitContainer
## The visual editor in the Story tab: a beat list and the selected beat's
## statements as cards. Every change is a small text edit (see [TaleEdit])
## reported through [signal source_changed]; the Story tab applies it to the
## text, so the .tale file stays the only saved format.

## Emitted with the whole new source after a card changes.
signal source_changed(new_source: String)
## Emitted when the player presses Ctrl+Z or Ctrl+Shift+Z (Ctrl+Y) here.
signal undo_requested
## Emitted when a field of a card gets focus, with the card's first source
## line (counting from 1), so the Story tab can report the selected line.
signal card_focused(line: int)
signal redo_requested

const KIND_COLORS := {
	TaleCard.Kind.NARRATION: Color(0.55, 0.62, 0.72),
	TaleCard.Kind.DIALOGUE: Color(0.45, 0.75, 0.55),
	TaleCard.Kind.ACTION: Color(0.85, 0.65, 0.3),
	TaleCard.Kind.CALL: Color(0.6, 0.5, 0.85),
	TaleCard.Kind.JUMP: Color(0.75, 0.45, 0.8),
	TaleCard.Kind.SET: Color(0.4, 0.7, 0.8),
	TaleCard.Kind.CHOICE: Color(0.9, 0.5, 0.5),
	TaleCard.Kind.CONDITION: Color(0.9, 0.75, 0.4),
	TaleCard.Kind.COMMENT: Color(0.5, 0.5, 0.5),
	TaleCard.Kind.SCRIPT: Color(0.6, 0.6, 0.6),
}
const KIND_TITLES := {
	TaleCard.Kind.NARRATION: "Narration",
	TaleCard.Kind.DIALOGUE: "Dialogue",
	TaleCard.Kind.ACTION: "Action",
	TaleCard.Kind.CALL: "Run beat",
	TaleCard.Kind.JUMP: "Jump",
	TaleCard.Kind.SET: "Set variable",
	TaleCard.Kind.CHOICE: "Choice",
	TaleCard.Kind.CONDITION: "Condition",
	TaleCard.Kind.COMMENT: "Comment",
	TaleCard.Kind.SCRIPT: "Script",
}
const NEW_CARDS := ["Narration", "Dialogue", "Choice", "Condition", "Jump", "Run beat", "Set variable", "Comment", "Script"]
const OPERATORS := ["=", "+=", "-=", "*=", "/="]

var source := ""
var doc: TaleDocument
var context: TaleCheckContext
var config: StoryConfig
var diagnostics: Array[TaleDiagnostic] = []
var current_beat := ""

var beat_list: ItemList
var cards_box: VBoxContainer
var _beat_name: LineEdit
var _scroll: ScrollContainer
var _beats := PackedStringArray()
var _focus_key := ""
## The last cards copied, used when the system clipboard is empty or not
## available (as in headless runs).
static var _copied := ""
## Choice and Condition cards folded to their header, as
## "beat:path" keys.
var _collapsed := {}
## Size of the speaker and mood thumbnails in pixels.
const THUMBNAIL_SIZE := 40
## Cast profiles by id, scanned the first time a thumbnail is needed.
var _profiles = null
## "id:mood" to thumbnail texture, or null when there is none.
var _thumbnails := {}
## Caret to put back in the refocused field after a rebuild, or (-1, -1).
var _focus_caret := Vector2i(-1, -1)


func _init() -> void:
	split_offset = 170
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	add_child(left)
	var beats_label := Label.new()
	beats_label.text = "Beats"
	left.add_child(beats_label)
	beat_list = ItemList.new()
	beat_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	beat_list.item_selected.connect(func(index: int) -> void: select_beat(beat_list.get_item_text(index)))
	left.add_child(beat_list)
	var add_beat := Button.new()
	add_beat.text = "+ Beat"
	add_beat.pressed.connect(add_new_beat)
	left.add_child(add_beat)
	var delete_beat := Button.new()
	delete_beat.text = "Delete Beat"
	delete_beat.pressed.connect(delete_current_beat)
	left.add_child(delete_beat)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var header := HBoxContainer.new()
	right.add_child(header)
	var label := Label.new()
	label.text = "beat"
	header.add_child(label)
	_beat_name = LineEdit.new()
	_beat_name.custom_minimum_size = Vector2(200, 0)
	_beat_name.set_meta("field_key", "beat:name")
	_beat_name.text_submitted.connect(func(_text: String) -> void: rename_beat(_beat_name.text))
	_beat_name.focus_exited.connect(func() -> void: rename_beat(_beat_name.text))
	header.add_child(_beat_name)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	cards_box = VBoxContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("separation", 6)
	_scroll.add_child(cards_box)


## Shows [param new_source]. Keeps the selected beat and, when possible,
## the focused field.
func set_source(new_source: String, new_context: TaleCheckContext = null, new_diagnostics: Array[TaleDiagnostic] = []) -> void:
	source = new_source
	if new_context != null:
		context = new_context
	diagnostics = new_diagnostics
	if config == null:
		config = preload("res://addons/storyteller/core/story.gd").load_config()
	doc = TaleParser.parse(source)
	_beats = PackedStringArray()
	for statement in doc.statements:
		if statement.kind == TaleNode.Kind.BEAT:
			_beats.append(statement.name)
	beat_list.clear()
	for beat_name in _beats:
		beat_list.add_item(beat_name)
	if current_beat not in _beats:
		current_beat = _beats[0] if not _beats.is_empty() else ""
	rebuild()


func select_beat(beat_name: String) -> void:
	current_beat = beat_name
	rebuild()


## Rebuilds the cards of the current beat from [member doc].
func rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused) and focused.has_meta("field_key") and _focus_key.is_empty():
		_focus_key = focused.get_meta("field_key")
		if focused is TextEdit and _focus_caret.x < 0:
			_focus_caret = Vector2i(focused.get_caret_line(), focused.get_caret_column())
	for child in cards_box.get_children():
		cards_box.remove_child(child)
		child.queue_free()
	var index := _beats.find(current_beat)
	if index >= 0:
		beat_list.select(index)
	_beat_name.text = current_beat
	var beat := doc.find_beat(current_beat) if doc != null else null
	if beat == null:
		var empty := Label.new()
		empty.text = "This tale has no beats yet. Click + Beat." if _beats.is_empty() else "Fix the errors in the text view to edit cards."
		cards_box.add_child(empty)
		return
	if doc.has_errors():
		var warning := Label.new()
		warning.text = "This tale has syntax errors. Cards may be incomplete until they are fixed in the text view."
		warning.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cards_box.add_child(warning)
	_add_card_list(cards_box, beat, "b")
	for field in get_fields().values():
		var line := _card_line_of(field)
		if line >= 0:
			field.focus_entered.connect(func() -> void: card_focused.emit(line))
	if not _focus_key.is_empty():
		_restore_focus.call_deferred(_focus_key, _focus_caret)
	_focus_caret = Vector2i(-1, -1)


## First source line of the card that holds [param control], or -1.
func _card_line_of(control: Node) -> int:
	var node := control
	while node != null and node != self:
		if node.has_meta("card"):
			var card: TaleCard = node.get_meta("card")
			return card.node.line_start
		node = node.get_parent()
	return -1


## Every card control, for tests: field key to Control.
func get_fields() -> Dictionary:
	var result := {}
	for control in find_children("*", "Control", true, false):
		if control.has_meta("field_key"):
			result[control.get_meta("field_key")] = control
	return result


## Card panels in display order (nested cards included).
func get_card_panels() -> Array[Control]:
	var result: Array[Control] = []
	for control in cards_box.find_children("*", "PanelContainer", true, false):
		if control.has_meta("card"):
			result.append(control)
	return result


func commit(new_source: String) -> void:
	# Fields commit when they lose focus, which also happens while the
	# editor is being closed.
	if new_source == source or not is_inside_tree():
		return
	source_changed.emit(new_source)


func add_new_beat() -> void:
	var beat_name := "new_beat"
	var n := 2
	while beat_name in _beats:
		beat_name = "new_beat_%d" % n
		n += 1
	current_beat = beat_name
	commit(TaleEdit.add_beat(source, doc, beat_name))


func delete_current_beat() -> void:
	var beat := doc.find_beat(current_beat)
	if beat == null:
		return
	var block := TaleEdit.span(beat)
	var lines := source.split("\n")
	# Take the blank lines after the beat with it; for the last beat, take
	# the blank lines before it instead.
	var first := block.x
	var last := block.y
	while last < lines.size() - 1 and lines[last].strip_edges().is_empty():
		last += 1
	if last >= lines.size() - 1:
		while first > 1 and lines[first - 2].strip_edges().is_empty():
			first -= 1
	current_beat = ""
	commit(TaleEdit.replace_lines(source, first, last, PackedStringArray()))


func rename_beat(new_name: String) -> void:
	new_name = new_name.strip_edges()
	var beat := doc.find_beat(current_beat) if doc != null else null
	if beat == null or new_name == current_beat or not new_name.is_valid_identifier() or new_name in _beats:
		return
	current_beat = new_name
	commit(TaleEdit.set_statement(source, beat, "beat %s:%s" % [new_name, TaleWriter.comment_suffix(beat)]))


func _gui_input(event: InputEvent) -> void:
	_handle_shortcut(event)


func _shortcut_input(event: InputEvent) -> void:
	if is_visible_in_tree():
		var focused := get_viewport().gui_get_focus_owner()
		if _handle_card_keys(event, focused):
			get_viewport().set_input_as_handled()
			return
		if focused == null or not is_ancestor_of(focused) or not (focused is LineEdit or focused is TextEdit):
			_handle_shortcut(event)


func _handle_shortcut(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not (event.ctrl_pressed or event.meta_pressed):
		return
	if event.keycode == KEY_Z and not event.shift_pressed:
		undo_requested.emit()
		accept_event()
	elif event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed):
		redo_requested.emit()
		accept_event()


## Alt+Up and Alt+Down move the card that holds [param focused], and
## Alt+Insert adds a narration card below it. Returns true when handled.
func _handle_card_keys(event: InputEvent, focused: Control) -> bool:
	if not (event is InputEventKey and event.pressed and event.alt_pressed) or event.ctrl_pressed or event.meta_pressed:
		return false
	if focused == null or not is_ancestor_of(focused):
		return false
	var path := card_path_of(focused)
	if path.is_empty() or not event.keycode in [KEY_UP, KEY_DOWN, KEY_INSERT]:
		return false
	# Leaving the field commits what was typed (which may rebuild the
	# cards) before the card moves.
	var key: String = focused.get_meta("field_key", "")
	focused.release_focus()
	match event.keycode:
		KEY_UP, KEY_DOWN:
			var step := -1 if event.keycode == KEY_UP else 1
			if move_card(path, step, key):
				return true
			_restore_focus(key, Vector2i(-1, -1))
			return true
		KEY_INSERT:
			var insert: MenuButton = get_fields().get(path + ":insert")
			if insert == null:
				_restore_focus(key, Vector2i(-1, -1))
				return true
			_focus_key = _card_key(path, 1) + ":text"
			insert.get_popup().id_pressed.emit(insert.get_popup().get_item_id(NEW_CARDS.find("Narration")))
			return true
	return false


## The path of the card that holds [param control], such as "b/3/o0/1",
## or "" when it is not in a card.
func card_path_of(control: Node) -> String:
	var node := control
	while node != null and node != self:
		if node.has_meta("card_path"):
			return node.get_meta("card_path")
		node = node.get_parent()
	return ""


## Moves the card at [param path] up ([param step] -1) or down (1) within
## its list. Focus follows the card when [param focus_key] names one of its
## fields. Returns false when the card is already at that end.
func move_card(path: String, step: int, focus_key := "") -> bool:
	var button: Button = get_fields().get(path + (":up" if step < 0 else ":down"))
	var index := int(path.get_slice("/", path.get_slice_count("/") - 1))
	var count := 0
	if button != null:
		var panel := button.get_parent().get_parent().get_parent()
		count = panel.get_parent().get_children().filter(func(child: Node) -> bool: return child.has_meta("card")).size()
	if button == null or index + step < 0 or index + step >= count:
		return false
	if focus_key.begins_with(path + ":") or focus_key.begins_with(path + "/"):
		_focus_key = _card_key(path, step) + focus_key.substr(path.length())
	button.pressed.emit()
	return true


## [param path] with its last index moved by [param step].
func _card_key(path: String, step: int) -> String:
	var cut := path.rfind("/")
	return path.substr(0, cut + 1) + str(int(path.substr(cut + 1)) + step)


# --- Card lists -----------------------------------------------------------

func _add_card_list(box: VBoxContainer, parent: TaleNode, path: String) -> void:
	var cards := TaleCard.build(parent, _beats, PackedStringArray(context.tales.keys()) if context else PackedStringArray())
	for i in cards.size():
		box.add_child(_make_card(cards[i], parent, "%s/%d" % [path, i]))
	var add := MenuButton.new()
	add.text = "+ Add card"
	add.flat = false
	add.set_meta("drop_parent", parent.line_start)
	add.set_meta("field_key", path + ":add")
	_fill_add_menu(add.get_popup(), func(text: String) -> void:
		commit(TaleEdit.append_to(source, doc, parent, _unit_text(text))))
	add.set_drag_forwarding(Callable(), _can_drop.bind(parent, cards.size()), _drop.bind(parent, cards.size()))
	box.add_child(add)


func _fill_add_menu(popup: PopupMenu, on_pick: Callable) -> void:
	popup.clear()
	for item in NEW_CARDS:
		popup.add_item(item)
	var actions := PopupMenu.new()
	actions.name = "Actions"
	var names := TaleSignatures.action_scripts().keys()
	names.sort()
	for action_name in names:
		actions.add_item(action_name)
	popup.add_child(actions)
	popup.add_submenu_node_item("Action", actions)
	popup.add_separator()
	popup.add_item("Paste")
	var paste_index := popup.item_count - 1
	popup.about_to_popup.connect(func() -> void:
		var can_paste := can_paste_text(paste_text())
		popup.set_item_disabled(paste_index, not can_paste)
		popup.set_item_tooltip(paste_index, "" if can_paste else "Copy a card first. Text from the clipboard is pasted when it is TaleScript lines."))
	popup.id_pressed.connect(func(id: int) -> void:
		var index := popup.get_item_index(id)
		if index == paste_index:
			var pasted := paste_text()
			if can_paste_text(pasted):
				on_pick.call(pasted)
			return
		var text := _new_card_text(popup.get_item_text(index))
		if not text.is_empty():
			on_pick.call(text))
	actions.id_pressed.connect(func(id: int) -> void:
		on_pick.call(_new_action_text(actions.get_item_text(actions.get_item_index(id)))))


## Copies the TaleScript of [param card] (with its nested cards) to the
## clipboard, indented with tabs.
func copy_cards(card: TaleCard) -> void:
	var text := TaleEdit.group_text(source, card.nodes)
	var unit := TaleEdit.indent_unit(doc)
	if unit != "\t":
		var lines := PackedStringArray()
		for line in text.split("\n"):
			var depth := 0
			while line.substr(depth * unit.length()).begins_with(unit):
				depth += 1
			lines.append("\t".repeat(depth) + line.substr(depth * unit.length()))
		text = "\n".join(lines)
	_copied = text
	DisplayServer.clipboard_set(text)


## What Paste would insert: the system clipboard, or the last copied cards
## when the clipboard is empty.
static func paste_text() -> String:
	var text := DisplayServer.clipboard_get() if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD) else ""
	return (text if not text.strip_edges().is_empty() else _copied).replace("\r\n", "\n").strip_edges(false, true)


## True when [param text] is one or more TaleScript statements that can go
## inside a beat.
static func can_paste_text(text: String) -> bool:
	if text.strip_edges().is_empty():
		return false
	var lines := PackedStringArray()
	for line in text.split("\n"):
		lines.append("\t" + line)
	var pasted := TaleParser.parse("beat pasted:\n" + "\n".join(lines) + "\n")
	return not pasted.has_errors() and pasted.statements.size() == 1


func _new_card_text(kind: String) -> String:
	var cast: Array = context.cast.keys() if context else []
	match kind:
		"Narration":
			return TaleWriter.narration("New line.")
		"Dialogue":
			return TaleWriter.dialogue(cast[0], "", "New line.") if not cast.is_empty() else TaleWriter.narration("New line.")
		"Choice":
			return "choose:\n\t%s\n\t\tpass\n\t%s\n\t\tpass" % [TaleWriter.option("Option 1"), TaleWriter.option("Option 2")]
		"Condition":
			return "%s\n\tpass" % TaleWriter.condition_header("if", "true")
		"Jump":
			return TaleWriter.jump(_beats[0] if not _beats.is_empty() else "start")
		"Run beat":
			return "%s()" % (_beats[0] if not _beats.is_empty() else "start")
		"Set variable":
			var vars := _variables()
			return TaleWriter.assign(vars[0] if not vars.is_empty() else "x", "=", "0")
		"Comment":
			return TaleWriter.comment("Note")
		"Script":
			return "pass"
	return ""


func _new_action_text(action_name: String) -> String:
	var args := PackedStringArray()
	for param in TaleSignatures.for_callee(action_name, context):
		if param["required"]:
			var options := TaleSignatures.choices(action_name, param["name"], config, context)
			args.append(TaleExpr.quote(options[0]) if not options.is_empty() else _placeholder(param["type"]))
	return TaleWriter.call_line(action_name, args)


func _placeholder(type: int) -> String:
	match type:
		TYPE_FLOAT:
			return "1.0"
		TYPE_INT:
			return "1"
		TYPE_BOOL:
			return "true"
	return "\"\""


# --- Cards ------------------------------------------------------------------

func _make_card(card: TaleCard, parent: TaleNode, path: String) -> Control:
	var panel := PanelContainer.new()
	panel.set_meta("card", card)
	panel.set_meta("card_path", path)
	panel.set_meta("card_kind", TaleCard.Kind.keys()[card.kind])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.17)
	style.border_width_left = 4
	style.border_color = KIND_COLORS[card.kind]
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	style.content_margin_left = 12
	var problems := _problems_for(card)
	if not problems.is_empty():
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.95, 0.35, 0.3) if problems[0].is_error() else Color(0.95, 0.8, 0.3)
		panel.tooltip_text = "\n".join(problems.map(func(d: TaleDiagnostic) -> String: return "Line %d: %s" % [d.line, d.message]))
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(_card_header(card, parent, path, panel))
	match card.kind:
		TaleCard.Kind.NARRATION:
			var text := _text_field(path + ":text", TaleCard.text_of(card.node), func(text: String) -> void:
				_set_line(card.node, TaleWriter.narration(text)))
			column.add_child(_markup_bar(text, path))
			column.add_child(text)
		TaleCard.Kind.DIALOGUE:
			column.add_child(_dialogue_fields(card, path))
		TaleCard.Kind.ACTION:
			column.add_child(_action_fields(card, path))
		TaleCard.Kind.CALL:
			var callee: String = TaleCard.call_parts(card.node)["callee"]
			column.add_child(_choice_field(path + ":target", callee, _targets(), func(text: String) -> void:
				_set_line(card.node, "%s()" % text)))
		TaleCard.Kind.JUMP:
			column.add_child(_choice_field(path + ":target", card.node.jump_target, _targets(), func(text: String) -> void:
				_set_line(card.node, TaleWriter.jump(text))))
		TaleCard.Kind.SET:
			column.add_child(_set_fields(card, path))
		TaleCard.Kind.CHOICE:
			_choice_lanes(column, card, path)
		TaleCard.Kind.CONDITION:
			_condition_lanes(column, card, path)
		TaleCard.Kind.COMMENT:
			column.add_child(_line_field(path + ":text", card.node.comment.strip_edges(), "", func(text: String) -> void:
				_set_line(card.node, TaleWriter.comment(text))))
		TaleCard.Kind.SCRIPT:
			column.add_child(_script_field(card, path))
	if is_folded(path):
		for i in range(1, column.get_child_count()):
			column.get_child(i).hide()
		var summary := Label.new()
		summary.text = _collapsed_summary(card)
		summary.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
		column.add_child(summary)
	return panel


## True when the card at [param path] in the current beat is folded.
func is_folded(path: String) -> bool:
	return _collapsed.has("%s:%s" % [current_beat, path])


## Folds or unfolds the card at [param path] in the current beat.
func set_folded(path: String, collapsed: bool) -> void:
	var key := "%s:%s" % [current_beat, path]
	if collapsed:
		_collapsed[key] = true
	else:
		_collapsed.erase(key)
	rebuild()


func _collapsed_summary(card: TaleCard) -> String:
	var count := 0
	var names := PackedStringArray()
	for lane in card.lanes:
		count += 1
		if card.kind == TaleCard.Kind.CHOICE and lane["node"].kind == TaleNode.Kind.OPTION:
			names.append("\"%s\"" % TaleCard.text_of(lane["node"]))
	if card.kind == TaleCard.Kind.CHOICE:
		return "%d options: %s" % [count, ", ".join(names)]
	return "%d branches" % count if count != 1 else "1 branch"


func _card_header(card: TaleCard, parent: TaleNode, path: String, panel: Control) -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = KIND_TITLES[card.kind]
	title.add_theme_color_override("font_color", KIND_COLORS[card.kind])
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.mouse_default_cursor_shape = Control.CURSOR_DRAG
	title.tooltip_text = "Drag to move"
	row.add_child(title)
	if card.kind == TaleCard.Kind.CHOICE or card.kind == TaleCard.Kind.CONDITION:
		var folded := is_folded(path)
		var fold := _small_button("▸" if folded else "▾", path + ":collapse", "Show the lanes" if folded else "Fold the lanes away", func() -> void:
			set_folded(path, not folded))
		row.add_child(fold)
		row.move_child(fold, 0)
	var siblings := TaleCard.build(parent, _beats)
	var index := -1
	for i in siblings.size():
		if siblings[i].node == card.node:
			index = i
	title.set_drag_forwarding(_drag.bind(card, panel), _can_drop.bind(parent, index), _drop.bind(parent, index))
	panel.set_drag_forwarding(Callable(), _can_drop.bind(parent, index), _drop.bind(parent, index))
	row.add_child(_small_button("▲", path + ":up", "Move up", func() -> void:
		if index > 0:
			commit(TaleEdit.move_group(source, doc, card.nodes, parent, index - 1))))
	row.add_child(_small_button("▼", path + ":down", "Move down", func() -> void:
		if index < siblings.size() - 1:
			commit(TaleEdit.move_group(source, doc, card.nodes, parent, index + 1))))
	var insert := MenuButton.new()
	insert.text = "+"
	insert.tooltip_text = "Add a card below"
	insert.set_meta("field_key", path + ":insert")
	_fill_add_menu(insert.get_popup(), func(text: String) -> void:
		commit(TaleEdit.insert_after(source, card.nodes.back(), _unit_text(text))))
	row.add_child(insert)
	row.add_child(_small_button("⧉", path + ":copy", "Copy this card, to paste in this or another tale", func() -> void:
		copy_cards(card)))
	row.add_child(_small_button("✕", path + ":delete", "Delete", func() -> void:
		commit(TaleEdit.delete_group(source, doc, card.nodes))))
	return row


func _dialogue_fields(card: TaleCard, path: String) -> Control:
	var column := VBoxContainer.new()
	var row := HBoxContainer.new()
	column.add_child(row)
	var speakers := PackedStringArray(context.cast.keys() if context else [])
	for constant in _string_constants():
		if constant not in speakers:
			speakers.append(constant)
	if card.node.name not in speakers:
		speakers.append(card.node.name)
	var speaker := _option_button(path + ":speaker", speakers, card.node.name)
	row.add_child(speaker)
	var moods := PackedStringArray(["(no mood)"])
	if context != null and context.cast.has(card.node.name):
		moods.append_array(context.cast[card.node.name])
	if not card.node.mood.is_empty() and card.node.mood not in moods:
		moods.append(card.node.mood)
	var mood := _option_button(path + ":mood", moods, card.node.mood if not card.node.mood.is_empty() else "(no mood)")
	row.add_child(mood)
	for i in speaker.item_count:
		speaker.set_item_icon(i, get_thumbnail(speaker.get_item_text(i), ""))
	for i in mood.item_count:
		mood.set_item_icon(i, get_thumbnail(card.node.name, "" if i == 0 else mood.get_item_text(i)))
	var text := _text_field(path + ":text", TaleCard.text_of(card.node), func(_text: String) -> void: pass)
	column.add_child(_markup_bar(text, path))
	column.add_child(text)
	var write := func() -> void:
		var picked_mood := mood.get_item_text(mood.selected)
		_set_line(card.node, TaleWriter.dialogue(speaker.get_item_text(speaker.selected), "" if picked_mood == "(no mood)" else picked_mood, text.text))
	speaker.item_selected.connect(func(_index: int) -> void: write.call())
	mood.item_selected.connect(func(_index: int) -> void: write.call())
	text.set_meta("commit", write)
	return column


func _action_fields(card: TaleCard, path: String) -> Control:
	var parts := TaleCard.call_parts(card.node)
	var callee: String = parts["callee"]
	var params := TaleSignatures.for_callee(callee, context)
	var grid := GridContainer.new()
	grid.columns = 2
	var name_label := Label.new()
	name_label.text = callee
	name_label.add_theme_font_size_override("font_size", 16)
	grid.add_child(name_label)
	var wait := CheckBox.new()
	wait.text = "Wait until it finishes"
	wait.button_pressed = parts["awaited"]
	wait.set_meta("field_key", path + ":await")
	grid.add_child(wait)
	if params.is_empty():
		var args := PackedStringArray(parts["args"])
		for pair in parts["named"]:
			args.append("%s = %s" % pair)
		var label := Label.new()
		label.text = "arguments"
		grid.add_child(label)
		var field := _line_field(path + ":args", ", ".join(args), "", func(text: String) -> void:
			_set_line(card.node, "%s%s(%s)" % ["await " if wait.button_pressed else "", callee, text]))
		grid.add_child(field)
		wait.toggled.connect(func(_on: bool) -> void: field.get_meta("commit").call())
		return grid
	var values := {}
	for i in parts["args"].size():
		if i < params.size():
			values[params[i]["name"]] = parts["args"][i]
	for pair in parts["named"]:
		values[pair[0]] = pair[1]
	var editors := {}
	var write := func() -> void:
		var positional := PackedStringArray()
		var named := []
		for param in params:
			var value: String = editors[param["name"]].call()
			if value.is_empty():
				if param["required"]:
					value = _placeholder(param["type"])
				else:
					continue
			if param["required"]:
				positional.append(value)
			else:
				named.append([param["name"], value])
		_set_line(card.node, TaleWriter.call_line(callee, positional, named, wait.button_pressed))
	for param in params:
		var label := Label.new()
		label.text = param["name"].replace("_", " ")
		grid.add_child(label)
		var key: String = "%s:%s" % [path, param["name"]]
		var current: String = values.get(param["name"], "")
		var options := TaleSignatures.choices(callee, param["name"], config, context)
		var control: Control
		if param["type"] == TYPE_BOOL:
			var picker := _option_button(key, PackedStringArray(["(default)", "true", "false"]), current if not current.is_empty() else "(default)")
			picker.item_selected.connect(func(_index: int) -> void: write.call())
			editors[param["name"]] = func() -> String:
				var text := picker.get_item_text(picker.selected)
				return "" if text == "(default)" else text
			control = picker
		elif param["type"] == TYPE_COLOR:
			control = _color_field(key, current, param["default"], write, editors, param["name"])
		else:
			var string_like: bool = param["type"] == TYPE_STRING or param["type"] == TYPE_NIL
			var shown := _display_value(current) if string_like else current
			var field := _choice_field(key, shown, options, func(_text: String) -> void: write.call(), _picture_finder(callee, param["name"]))
			field.get_meta("line_edit").placeholder_text = _default_text(param)
			var line: LineEdit = field.get_meta("line_edit")
			editors[param["name"]] = func() -> String:
				return _source_value(line.text) if string_like else line.text.strip_edges()
			control = field
		grid.add_child(control)
	wait.toggled.connect(func(_on: bool) -> void: write.call())
	return grid


func _set_fields(card: TaleCard, path: String) -> Control:
	var row := HBoxContainer.new()
	var parts := {}
	var target := _choice_field(path + ":target", card.node.target.to_source(), assignable_names(), func(_text: String) -> void:
		parts["write"].call())
	target.size_flags_horizontal = Control.SIZE_FILL
	target.get_meta("line_edit").placeholder_text = "variable"
	row.add_child(target)
	var op := _option_button(path + ":op", PackedStringArray(OPERATORS), card.node.op)
	row.add_child(op)
	var value := _line_field(path + ":value", card.node.expr.to_source(), "value", func(_text: String) -> void: pass)
	row.add_child(value)
	var write := func() -> void:
		_set_line(card.node, TaleWriter.assign(target.get_meta("line_edit").text.strip_edges(), op.get_item_text(op.selected), value.get_meta("line_edit").text.strip_edges()))
	parts["write"] = write
	value.set_meta("commit", write)
	_bind_commit(value)
	op.item_selected.connect(func(_index: int) -> void: write.call())
	return row


func _choice_lanes(column: VBoxContainer, card: TaleCard, path: String) -> void:
	# Picture fields show for the "pictures" style or once any option has one.
	var with_pictures := _choice_style(card.node) == "pictures"
	for lane in card.lanes:
		with_pictures = with_pictures or _has_annotation(lane["node"], "picture")
	for i in card.lanes.size():
		var lane: Dictionary = card.lanes[i]
		var node: TaleNode = lane["node"]
		var lane_path := "%s/o%d" % [path, i]
		var lane_box := VBoxContainer.new()
		column.add_child(lane_box)
		var row := HBoxContainer.new()
		lane_box.add_child(row)
		if node.kind == TaleNode.Kind.TIMEOUT:
			var label := Label.new()
			label.text = "When time runs out:"
			row.add_child(label)
		else:
			var text := _line_field(lane_path + ":text", TaleCard.text_of(node), "option text", func(_text: String) -> void: pass)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
			var condition := _line_field(lane_path + ":condition", node.condition.to_source() if node.condition else "", "only if… (optional)", func(_text: String) -> void: pass)
			row.add_child(condition)
			var once := _check(lane_path + ":once", "Once", _has_annotation(node, "once"))
			row.add_child(once)
			var disabled := _check(lane_path + ":show_disabled", "Show when unavailable", _has_annotation(node, "show_disabled"))
			row.add_child(disabled)
			var picture: Control = null
			var parts := {}
			if with_pictures:
				var pictures := StoryAssets.list_names(config.choice_picture_folder, StoryAssets.IMAGE_EXTENSIONS) if config != null else PackedStringArray()
				picture = _choice_field(lane_path + ":picture", _annotation_text(node, "picture"), pictures, func(_text: String) -> void:
					parts["write"].call(), func(picture_name: String) -> Texture2D:
						return asset_thumbnail(StoryAssets.find(config.choice_picture_folder, picture_name, StoryAssets.IMAGE_EXTENSIONS)))
				picture.size_flags_horizontal = Control.SIZE_FILL
				picture.get_meta("line_edit").placeholder_text = "picture"
				row.add_child(picture)
			var write := func() -> void:
				var keep: Array[TaleExpr] = []
				for annotation in node.annotations:
					if annotation.name not in ["once", "show_disabled", "picture"]:
						keep.append(annotation)
				var prefix := TaleWriter.annotations_prefix(keep)
				var picture_name := "" if picture == null else String(picture.get_meta("line_edit").text).strip_edges()
				if not picture_name.is_empty():
					prefix += "@picture(%s) " % TaleExpr.quote(picture_name)
				prefix += ("@once " if once.button_pressed else "") + ("@show_disabled " if disabled.button_pressed else "")
				_set_line(node, prefix + TaleWriter.option(text.get_meta("line_edit").text, condition.get_meta("line_edit").text) + TaleWriter.comment_suffix(node))
			text.set_meta("commit", write)
			condition.set_meta("commit", write)
			_bind_commit(text)
			_bind_commit(condition)
			parts["write"] = write
			once.toggled.connect(func(_on: bool) -> void: write.call())
			disabled.toggled.connect(func(_on: bool) -> void: write.call())
		if card.lanes.size() > 1:
			row.add_child(_small_button("✕", lane_path + ":delete", "Remove this option", func() -> void:
				commit(TaleEdit.delete(source, doc, node))))
		var nested := VBoxContainer.new()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_child(nested)
		lane_box.add_child(margin)
		_add_card_list(nested, node, lane_path)
	var add := _small_button("+ Option", path + ":add_option", "Add an option", func() -> void:
		var last_option: TaleNode = null
		for lane in card.lanes:
			if lane["node"].kind == TaleNode.Kind.OPTION:
				last_option = lane["node"]
		var text := _unit_text("%s\n\tpass" % TaleWriter.option("New option"))
		commit(TaleEdit.insert_after(source, last_option, text) if last_option != null else TaleEdit.append_to(source, doc, card.node, text)))
	column.add_child(add)


func _condition_lanes(column: VBoxContainer, card: TaleCard, path: String) -> void:
	var has_else := false
	for i in card.lanes.size():
		var node: TaleNode = card.lanes[i]["node"]
		var lane_path := "%s/c%d" % [path, i]
		var row := HBoxContainer.new()
		column.add_child(row)
		var keyword := Label.new()
		match node.kind:
			TaleNode.Kind.IF:
				keyword.text = "If"
			TaleNode.Kind.ELIF:
				keyword.text = "Else if"
			_:
				keyword.text = "Otherwise"
				has_else = true
		row.add_child(keyword)
		if node.kind != TaleNode.Kind.ELSE:
			var word := "if" if node.kind == TaleNode.Kind.IF else "elif"
			var field := _line_field(lane_path + ":condition", node.expr.to_source() if node.expr else "", "condition", func(text: String) -> void:
				_set_line(node, TaleWriter.condition_header(word, text)))
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(field)
		if i > 0:
			row.add_child(_small_button("✕", lane_path + ":delete", "Remove this branch", func() -> void:
				var lines := TaleEdit.span(node)
				commit(TaleEdit.replace_lines(source, lines.x, lines.y, PackedStringArray()))))
		var nested := VBoxContainer.new()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_child(nested)
		column.add_child(margin)
		_add_card_list(nested, node, lane_path)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var last: TaleNode = card.lanes.back()["node"]
	buttons.add_child(_small_button("+ Else if", path + ":add_elif", "Add another condition", func() -> void:
		var text := _unit_text("%s\n\tpass" % TaleWriter.condition_header("elif", "true"))
		commit(TaleEdit.insert_before(source, last, text) if last.kind == TaleNode.Kind.ELSE else TaleEdit.insert_after(source, last, text))))
	if not has_else:
		buttons.add_child(_small_button("+ Otherwise", path + ":add_else", "Add an else branch", func() -> void:
			commit(TaleEdit.insert_after(source, last, _unit_text("else:\n\tpass")))))


func _script_field(card: TaleCard, path: String) -> Control:
	var edit := CodeEdit.new()
	edit.text = TaleEdit.group_text(source, card.nodes)
	edit.custom_minimum_size = Vector2(0, 26 * mini(edit.get_line_count() + 1, 12))
	edit.scroll_fit_content_height = true
	edit.syntax_highlighter = TaleSyntaxHighlighter.new()
	edit.set_meta("field_key", path + ":script")
	var write := func() -> void:
		if edit.text != TaleEdit.group_text(source, card.nodes):
			var block := TaleEdit.group_span(card.nodes)
			var lines := PackedStringArray()
			for line in edit.text.split("\n"):
				lines.append(card.node.indent + line if not line.strip_edges().is_empty() else "")
			commit(TaleEdit.replace_lines(source, block.x, block.y, lines))
	edit.set_meta("commit", write)
	edit.focus_exited.connect(write)
	return edit


# --- Fields -----------------------------------------------------------------

## A multi-line text field for dialogue and narration. Commits when focus
## leaves it.
func _text_field(key: String, text: String, on_commit: Callable) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = text
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.custom_minimum_size = Vector2(0, 34)
	edit.set_meta("field_key", key)
	edit.set_meta("commit", func() -> void: on_commit.call(edit.text))
	edit.focus_exited.connect(func() -> void: edit.get_meta("commit").call())
	return edit


## Buttons above a text field that write text tags, so writers need not
## type them: bold and italic, pauses, slower and faster typing, sounds,
## and the project's named text styles. Selected text is wrapped; with no
## selection the tags go in at the caret.
func _markup_bar(edit: TextEdit, path: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for entry in [
		["bold", "B", "Bold", "[b]", "[/b]"],
		["italic", "I", "Italic", "[i]", "[/i]"],
		["pause", "Pause", "Wait for the player, then keep typing", "[pause]", ""],
		["wait", "Wait", "Wait half a second", "[pause=0.5]", ""],
		["slow", "Slow", "Type the selected text at half speed", "[speed=0.5]", "[/speed]"],
		["fast", "Fast", "Type the selected text twice as fast", "[speed=2.0]", "[/speed]"],
	]:
		var button := _small_button(entry[1], path + ":markup:" + entry[0], entry[2], func() -> void:
			apply_markup(edit, entry[3], entry[4]))
		button.focus_mode = Control.FOCUS_NONE
		row.add_child(button)
	var sounds := TaleSignatures.choices("sound", "name", config, context) if config != null else PackedStringArray()
	if not sounds.is_empty():
		row.add_child(_markup_menu(edit, path + ":markup:sound", "Sound", "Play a sound when typing reaches the caret", sounds, func(sound_name: String) -> Array:
			return ["[sound=%s]" % sound_name, ""]))
	var styles := PackedStringArray(config.text_styles.keys()) if config != null else PackedStringArray()
	if not styles.is_empty():
		styles.sort()
		row.add_child(_markup_menu(edit, path + ":markup:style", "Style", "Show the selected text in one of the project's text styles", styles, func(style_name: String) -> Array:
			return ["[%s]" % style_name, "[/%s]" % style_name]))
	return row


func _markup_menu(edit: TextEdit, key: String, text: String, tooltip: String, items: PackedStringArray, tags_for: Callable) -> MenuButton:
	var menu := MenuButton.new()
	menu.text = text + " ▾"
	menu.tooltip_text = tooltip
	menu.flat = true
	menu.focus_mode = Control.FOCUS_NONE
	menu.set_meta("field_key", key)
	for item in items:
		menu.get_popup().add_item(item)
	menu.get_popup().index_pressed.connect(func(index: int) -> void:
		var tags: Array = tags_for.call(items[index])
		apply_markup(edit, tags[0], tags[1]))
	return menu


## Wraps the selection in [param edit] with [param open] and [param close],
## or inserts them at the caret, then commits the field. With no selection
## the caret ends up between the two tags, ready for typing.
func apply_markup(edit: TextEdit, open: String, close: String) -> void:
	var selected := ""
	if edit.has_selection():
		selected = edit.get_selected_text()
		edit.delete_selection()
	edit.insert_text_at_caret(open + selected + close)
	if selected.is_empty() and not close.is_empty():
		edit.set_caret_column(edit.get_caret_column() - close.length())
	_focus_key = edit.get_meta("field_key")
	_focus_caret = Vector2i(edit.get_caret_line(), edit.get_caret_column())
	edit.get_meta("commit").call()


## A one-line field. Commits on Enter and when focus leaves it. The returned
## control holds the LineEdit in meta "line_edit".
func _line_field(key: String, text: String, placeholder: String, on_commit: Callable) -> Control:
	var line := LineEdit.new()
	line.text = text
	line.placeholder_text = placeholder
	line.custom_minimum_size = Vector2(140, 0)
	line.set_meta("field_key", key)
	line.set_meta("line_edit", line)
	line.set_meta("commit", func() -> void: on_commit.call(line.text))
	_bind_commit(line)
	return line


## A one-line field with a ▾ menu of suggested values.
## A one-line field with a list of [param options] beside it. When given,
## [param icon_for] returns a picture for an option name, or null.
func _choice_field(key: String, text: String, options: PackedStringArray, on_commit: Callable, icon_for := Callable()) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := LineEdit.new()
	line.text = text
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.custom_minimum_size = Vector2(140, 0)
	line.set_meta("field_key", key)
	line.set_meta("commit", func() -> void: on_commit.call(line.text))
	_bind_commit(line)
	row.add_child(line)
	row.set_meta("line_edit", line)
	line.set_meta("line_edit", line)
	if not options.is_empty():
		var menu := MenuButton.new()
		menu.text = "▾"
		menu.flat = false
		menu.tooltip_text = "Pick from the list. Type part of a name first to narrow it."
		_fill_choices(menu.get_popup(), options, icon_for, "")
		menu.about_to_popup.connect(func() -> void:
			_fill_choices(menu.get_popup(), options, icon_for, line.text))
		menu.get_popup().id_pressed.connect(func(id: int) -> void:
			line.text = menu.get_popup().get_item_text(menu.get_popup().get_item_index(id))
			on_commit.call(line.text))
		row.add_child(menu)
	return row


## Lists [param options] in [param popup]. When [param typed] is part of
## a name but not a whole one, only the names containing it are listed
## (all of them when none do).
func _fill_choices(popup: PopupMenu, options: PackedStringArray, icon_for: Callable, typed: String) -> void:
	popup.clear()
	var search := typed.strip_edges().to_lower()
	var shown := options
	if not search.is_empty() and typed.strip_edges() not in options:
		var matching := PackedStringArray()
		for option in options:
			if search in option.to_lower():
				matching.append(option)
		if not matching.is_empty():
			shown = matching
	for option in shown:
		popup.add_item(option)
		if icon_for.is_valid():
			var icon: Texture2D = icon_for.call(option)
			if icon != null:
				popup.set_item_icon(popup.item_count - 1, icon)


func _color_field(key: String, current: String, default: Variant, write: Callable, editors: Dictionary, param_name: String) -> Control:
	var row := HBoxContainer.new()
	var use := CheckBox.new()
	use.text = "Set"
	use.button_pressed = not current.is_empty()
	row.add_child(use)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(60, 26)
	picker.set_meta("field_key", key)
	picker.color = _evaluate_color(current) if not current.is_empty() else (default if default is Color else Color.WHITE)
	row.add_child(picker)
	editors[param_name] = func() -> String:
		if not use.button_pressed:
			return ""
		if not current.is_empty() and _evaluate_color(current) == picker.color:
			return current
		var c := picker.color
		var channels := [snappedf(c.r, 0.01), snappedf(c.g, 0.01), snappedf(c.b, 0.01)]
		if c.a < 1.0:
			channels.append(snappedf(c.a, 0.01))
		return "Color(%s)" % ", ".join(channels.map(func(v: float) -> String: return str(v)))
	picker.popup_closed.connect(func() -> void:
		use.button_pressed = true
		write.call())
	use.toggled.connect(func(_on: bool) -> void: write.call())
	return row


func _option_button(key: String, items: PackedStringArray, selected: String) -> OptionButton:
	var button := OptionButton.new()
	for item in items:
		button.add_item(item)
	button.select(maxi(items.find(selected), 0))
	button.set_meta("field_key", key)
	return button


## A small picture of cast member [param id] in [param mood] (their default
## mood when empty): the top of the drawn figure, where the face usually
## is. Null when the id is not a cast member or the look has no picture.
func get_thumbnail(id: String, mood: String) -> Texture2D:
	if _profiles == null:
		_profiles = StoryStage.scan_cast(config.cast_folder) if config != null else {}
	var profile: CastProfile = _profiles.get(id)
	if profile == null or profile.look == null:
		return null
	if mood.is_empty():
		mood = profile.default_mood
		if mood.is_empty():
			var moods := profile.look.get_moods()
			mood = moods[0] if not moods.is_empty() else ""
	var key := "%s:%s" % [id, mood]
	if not _thumbnails.has(key):
		_thumbnails[key] = _make_thumbnail(profile.look.get_preview(mood))
	return _thumbnails[key]


## Returns pictures for the list of [param param] of [param callee]: the
## backdrop, CG, or prop images, or the cast member's moods. An invalid
## Callable when the values have no pictures.
func _picture_finder(callee: String, param: String) -> Callable:
	if config == null:
		return Callable()
	var method := callee.get_slice(".", 1) if "." in callee else callee
	match [method, param]:
		["backdrop", "name"]:
			return func(value: String) -> Texture2D:
				return asset_thumbnail(StoryAssets.find(config.backdrop_folder, value, StoryAssets.IMAGE_EXTENSIONS))
		["cg", "name"]:
			var cgs := StoryAssets.scan_cgs(config.cg_folder)
			return func(value: String) -> Texture2D:
				var variants: PackedStringArray = cgs.get(value, PackedStringArray())
				return asset_thumbnail(StoryAssets.find_cg(config.cg_folder, value, StoryAssets.default_cg_variant(variants)))
		["prop", "name"], ["hide_prop", "name"]:
			return func(value: String) -> Texture2D:
				return asset_thumbnail(StoryAssets.find(config.prop_folder, value, StoryAssets.IMAGE_EXTENSIONS))
		["enter", "mood_name"]:
			var owner := callee.get_slice(".", 0)
			return func(value: String) -> Texture2D:
				return get_thumbnail(owner, value)
	return Callable()


## A small copy of the image at [param path], at most [constant
## THUMBNAIL_SIZE] pixels high, or null when there is no image.
func asset_thumbnail(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _thumbnails.has(path):
		var texture := load(path) as Texture2D
		var image := texture.get_image() if texture != null else null
		if image == null:
			_thumbnails[path] = null
		else:
			image = image.duplicate()
			if image.is_compressed():
				image.decompress()
			var height := THUMBNAIL_SIZE
			var width := maxi(1, roundi(float(image.get_width()) * height / image.get_height()))
			image.resize(width, height, Image.INTERPOLATE_BILINEAR)
			_thumbnails[path] = ImageTexture.create_from_image(image)
	return _thumbnails[path]


static func _make_thumbnail(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return null
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var side := mini(used.size.x, used.size.y)
	var crop := image.get_region(Rect2i(used.position.x + (used.size.x - side) / 2, used.position.y, side, side))
	crop.resize(THUMBNAIL_SIZE, THUMBNAIL_SIZE, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(crop)


func _check(key: String, text: String, pressed: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = pressed
	box.set_meta("field_key", key)
	return box


func _small_button(text: String, key: String, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.flat = true
	button.set_meta("field_key", key)
	button.pressed.connect(action)
	return button


func _bind_commit(field: Control) -> void:
	var line: LineEdit = field.get_meta("line_edit") if field.has_meta("line_edit") else field as LineEdit
	if line == null or line.has_meta("bound"):
		return
	line.set_meta("bound", true)
	var run := func() -> void:
		if field.has_meta("commit"):
			field.get_meta("commit").call()
		elif line.has_meta("commit"):
			line.get_meta("commit").call()
	line.text_submitted.connect(func(_text: String) -> void: run.call())
	line.focus_exited.connect(run)


# --- Helpers ----------------------------------------------------------------

## Rewrites [param node]'s line as [param text], keeping its annotations
## (for lines and actions) and its end-of-line comment.
func _set_line(node: TaleNode, text: String) -> void:
	var prefix := ""
	if node.kind in [TaleNode.Kind.NARRATION, TaleNode.Kind.DIALOGUE, TaleNode.Kind.EXPRESSION, TaleNode.Kind.JUMP, TaleNode.Kind.ASSIGN]:
		prefix = TaleWriter.annotations_prefix(node.annotations)
	commit(TaleEdit.set_statement(source, node, prefix + text + TaleWriter.comment_suffix(node)))


## Replaces leading tabs of [param text] with the file's indentation step.
func _unit_text(text: String) -> String:
	var unit := TaleEdit.indent_unit(doc)
	if unit == "\t":
		return text
	var out := PackedStringArray()
	for line in text.split("\n"):
		var depth := 0
		while depth < line.length() and line[depth] == "\t":
			depth += 1
		out.append(unit.repeat(depth) + line.substr(depth))
	return "\n".join(out)


func _problems_for(card: TaleCard) -> Array:
	var block := TaleEdit.group_span(card.nodes)
	var header_end: int = card.nodes[0].line_end
	var found := []
	for diagnostic in diagnostics:
		var inside_header := diagnostic.line >= block.x and diagnostic.line <= header_end
		var leaf := card.lanes.is_empty() and diagnostic.line >= block.x and diagnostic.line <= block.y
		if inside_header or leaf:
			found.append(diagnostic)
	return found


func _targets() -> PackedStringArray:
	var targets := PackedStringArray(_beats)
	if context != null:
		for tale_name in context.tales:
			for beat_name in context.tales[tale_name]["beats"]:
				targets.append("%s.%s" % [tale_name, beat_name])
	return targets


func _variables() -> PackedStringArray:
	var names := PackedStringArray()
	for statement in doc.statements:
		if statement.kind == TaleNode.Kind.VAR:
			names.append(statement.name)
	return names


## Everything a Set variable card can change: this tale's variables, then
## other tales' as [code]tale.variable[/code], then cast fields as
## [code]id.field[/code].
func assignable_names() -> PackedStringArray:
	var names := _variables()
	if context != null:
		var tale_names := context.tales.keys()
		tale_names.sort()
		for tale_name in tale_names:
			if tale_name == context.tale_name:
				continue
			for variable in context.tales[tale_name].get("vars", []):
				names.append("%s.%s" % [tale_name, variable])
		var ids := context.cast_fields.keys()
		ids.sort()
		for id in ids:
			for field in context.cast_fields[id]:
				names.append("%s.%s" % [id, field])
	return names


func _string_constants() -> PackedStringArray:
	var names := PackedStringArray()
	for statement in doc.statements:
		if statement.kind == TaleNode.Kind.CONST and statement.expr != null and statement.expr.kind == TaleExpr.Kind.LITERAL and statement.expr.value is String:
			names.append(statement.name)
	return names


## Text argument of [param node]'s annotation [param annotation_name], or "".
static func _annotation_text(node: TaleNode, annotation_name: String) -> String:
	for annotation in node.annotations:
		if annotation.name == annotation_name and annotation.args.size() == 1 and annotation.args[0].value is String:
			return annotation.args[0].value
	return ""


## The literal style argument of a choose block, or "".
static func _choice_style(node: TaleNode) -> String:
	if node.expr == null or not node.expr.named_args.has("style"):
		return ""
	var style: TaleExpr = node.expr.named_args["style"]
	return style.value if style.kind == TaleExpr.Kind.LITERAL and style.value is String else ""


static func _has_annotation(node: TaleNode, annotation_name: String) -> bool:
	for annotation in node.annotations:
		if annotation.name == annotation_name:
			return true
	return false


## How a value is shown in a text field: string literals without quotes,
## anything else as "=expression".
static func _display_value(value_source: String) -> String:
	if value_source.is_empty():
		return ""
	var parsed := TaleParser.parse_expression(value_source)
	if not parsed["error"] and parsed["expr"].kind == TaleExpr.Kind.LITERAL and parsed["expr"].value is String:
		return parsed["expr"].value
	return "=" + value_source


## The source for a text field's value: quoted text, or the expression
## after "=". Empty means "not given".
static func _source_value(text: String) -> String:
	if text.is_empty():
		return ""
	if text.begins_with("="):
		return text.substr(1).strip_edges()
	return TaleExpr.quote(text)


static func _default_text(param: Dictionary) -> String:
	if param["required"]:
		return "required"
	var value: Variant = param["default"]
	if value is String:
		return "default: \"%s\"" % value if not value.is_empty() else "default: none"
	return "default: %s" % str(value)


static func _evaluate_color(value_source: String) -> Color:
	var expression := Expression.new()
	if expression.parse(value_source) == OK:
		var value: Variant = expression.execute()
		if value is Color:
			return value
	return Color.WHITE


func _restore_focus(key: String, caret: Vector2i) -> void:
	_focus_key = ""
	var fields := get_fields()
	if fields.has(key) and fields[key].is_visible_in_tree():
		fields[key].grab_focus()
		if fields[key] is TextEdit and caret.x >= 0:
			fields[key].set_caret_line(caret.x)
			fields[key].set_caret_column(caret.y)


# --- Drag and drop -------------------------------------------------------------

func _drag(_at: Vector2, card: TaleCard, panel: Control) -> Variant:
	var preview := Label.new()
	preview.text = KIND_TITLES[card.kind]
	set_drag_preview(preview)
	return {"tale_card_lines": card.nodes.map(func(node: TaleNode) -> int: return node.line_start), "panel": panel}


func _can_drop(_at: Vector2, data: Variant, _parent: TaleNode, _index: int) -> bool:
	return data is Dictionary and data.has("tale_card_lines")


## Drops a dragged card before the card at [param index] of [param parent]
## (or at the end when [param index] is the number of cards).
func _drop(_at: Vector2, data: Variant, parent: TaleNode, index: int) -> void:
	var nodes := []
	for line in data["tale_card_lines"]:
		nodes.append(TaleEdit.find_at_line(doc, line))
	if nodes.has(null):
		return
	# A card can't go inside itself, such as a choice into its own option.
	var dragged := TaleEdit.group_span(nodes)
	if parent.line_start >= dragged.x and parent.line_start <= dragged.y:
		return
	var siblings := TaleEdit.content_children(parent)
	var target := index
	for node in nodes:
		var position := siblings.find(node)
		if position >= 0 and position < index:
			target -= 1
	commit(TaleEdit.move_group(source, doc, nodes, parent, maxi(target, 0)))

class_name StudioBlockEditor
extends HBoxContainer
## The block editor of Visual Novel StoryTeller Studio (docs/studio-design.md
## §4 and §5): scene tabs, a palette of colored blocks, and the chosen
## scene's blocks in the order they play. Blocks are dragged in from the
## palette (or tapped to add them), moved by dragging, and deleted by
## dragging them back to the palette. Every change is a small text edit made
## with [TaleEdit], so the .tale text stays the only saved format, and every
## change can be undone.

## Emitted with the whole new source after a change, an undo, or a redo.
signal source_changed(new_source: String)
## Emitted when a block is tapped, with its first source line (from 1).
signal block_selected(line: int)

const FONT_SIZE := 20
## Smallest height of anything a finger taps (docs/studio-design.md §2).
const TOUCH_SIZE := 44
const LONG_PRESS_TIME := 0.5
## How far a finger moves before a press becomes a drag, in pixels.
const DRAG_DISTANCE := 8.0
const UNDO_LIMIT := 200
const PALETTE_WIDTH := 280
## Words shown on a field that has no value yet.
const FIELD_HINTS := {"character": "someone", "face": "face", "picture": "picture", "track": "music", "sound": "sound",
	"scene": "scene", "number": "number", "word": "name", "code": "code", "text": "…"}
## Fields a tap moves to their next choice, with the choices in order.
const CYCLE_FIELDS := {"position": StoryBlocks.POSITIONS, "comparison": StoryBlocks.COMPARISONS,
	"motion": StoryBlocks.MOTIONS, "weather": StoryBlocks.WEATHERS}
## Words of the arms of an If block, by keyword and by test.
const ARM_WORDS := {"if": "If", "elif": "Or if", "else": "Otherwise"}
const TEST_WORDS := {"compare": "{number} {comparison} {value}", "visited": "the player has been to {scene}", "code": "{condition}"}
## The question asked when a field is changed by typing.
const FIELD_QUESTIONS := {"text": "What is said?", "prompt": "What does the game ask?", "character": "Who?",
	"face": "Which face?", "picture": "Which picture?", "track": "Which music?", "sound": "Which sound?",
	"seconds": "How many seconds?", "scene": "Which scene?", "number": "Which number?", "value": "What number?",
	"word": "Keep the name in", "code": "TaleScript", "condition": "Test"}
const _DIALOG_TITLES := {"note": "Note"}

var source := ""
var doc: TaleDocument
var current_scene := ""
var current_group := "talk"
## Shows the Code block in the palette (the "advanced blocks" setting).
var show_code_blocks := false:
	set(value):
		show_code_blocks = value
		show_group(current_group)
var config: StoryConfig

## One button per scene, in a row that wraps.
var scene_tabs: HFlowContainer
var palette: VBoxContainer
## The chosen scene's blocks.
var stack: VBoxContainer
var _scroll: ScrollContainer
var _palette_blocks: VBoxContainer
var _group_buttons := {}
var _drop_line: ColorRect
var _message: Label
var _dialog: Control

var _scenes := PackedStringArray()
## Every list of blocks on screen: the scene's own and one per arm, as
## [code]{"parent": TaleNode, "cards": Array[TaleCard], "box": VBoxContainer}[/code].
## Lists inside a block come after the list that holds the block.
var _lanes: Array[Dictionary] = []
var _undo := PackedStringArray()
var _redo := PackedStringArray()
var _selected_line := -1
## Cast member ids, scanned the first time a new block needs a character.
var _cast = null

var _pressing: Control
var _press_at := Vector2.ZERO
var _press_time := 0.0
## True while the press started on a field chip.
var _from_chip := false
## True after a long press, so lifting the finger does nothing more.
var _swallow_release := false
## The drag under way: [code]{"control", "offset", "at"}[/code], or empty.
var _drag := {}
var _ghost: Control
## Where the dragged block would land: [code]{"lane", "index"}[/code],
## [code]{"delete": true}[/code], or empty.
var _target := {}


func _init() -> void:
	add_theme_constant_override("separation", 12)
	_build_palette()
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(center)
	scene_tabs = HFlowContainer.new()
	scene_tabs.add_theme_constant_override("h_separation", 6)
	scene_tabs.add_theme_constant_override("v_separation", 6)
	center.add_child(scene_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(_scroll)
	stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 6)
	_scroll.add_child(stack)
	_message = _label("", FONT_SIZE - 2, Color(1, 0.85, 0.5))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	center.add_child(_message)
	_drop_line = ColorRect.new()
	_drop_line.color = Color.WHITE
	_drop_line.top_level = true
	_drop_line.z_index = 10
	_drop_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_line.visible = false
	add_child(_drop_line)


## Shows [param new_source], keeping the chosen scene when it is still
## there. Undo history starts over unless [param keep_history] is true.
func set_source(new_source: String, keep_history := false) -> void:
	if not keep_history:
		_undo.clear()
		_redo.clear()
	_apply(new_source)


func _apply(new_source: String) -> void:
	source = new_source
	doc = TaleParser.parse(source)
	if config == null:
		config = preload("res://addons/storyteller/core/story.gd").load_config()
	_scenes = PackedStringArray()
	for statement in doc.statements:
		if statement.kind == TaleNode.Kind.BEAT:
			_scenes.append(statement.name)
	if current_scene not in _scenes:
		current_scene = _scenes[0] if not _scenes.is_empty() else ""
	_update_tabs()
	rebuild()


## Applies [param new_source] as one change that can be undone. A change
## that would break the tale is refused with a message. Returns true when
## the source changed.
func commit(new_source: String) -> bool:
	new_source = TaleEdit.fill_empty_blocks(new_source)
	if new_source == source:
		return false
	if TaleParser.parse(new_source).has_errors() and not doc.has_errors():
		show_message("That doesn't fit there, so nothing changed.")
		return false
	_undo.append(source)
	if _undo.size() > UNDO_LIMIT:
		_undo.remove_at(0)
	_redo.clear()
	_apply(new_source)
	source_changed.emit(source)
	return true


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(source)
	var previous := _undo[_undo.size() - 1]
	_undo.remove_at(_undo.size() - 1)
	_apply(previous)
	source_changed.emit(source)
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(source)
	var next := _redo[_redo.size() - 1]
	_redo.remove_at(_redo.size() - 1)
	_apply(next)
	source_changed.emit(source)
	return true


## Shows a short message under the blocks for a few seconds.
func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_interval(4.0)
		tween.tween_callback(func() -> void: if _message.text == text: _message.visible = false)


# --- Scenes ---------------------------------------------------------------

## The name students see for the beat [param beat_name]: "toy_box" is
## "Toy box".
static func scene_title(beat_name: String) -> String:
	var words := beat_name.replace("_", " ").strip_edges()
	return words.left(1).to_upper() + words.substr(1) if not words.is_empty() else beat_name


func select_scene(beat_name: String) -> void:
	current_scene = beat_name
	_selected_line = -1
	_update_tabs()
	rebuild()


## Adds an empty scene at the end of the story and shows it.
func add_scene() -> void:
	var n := _scenes.size() + 1
	while "scene_%d" % n in _scenes:
		n += 1
	var previous := current_scene
	current_scene = "scene_%d" % n
	if not commit(TaleEdit.add_beat(source, doc, current_scene)):
		current_scene = previous


func get_scenes() -> PackedStringArray:
	return _scenes


func _update_tabs() -> void:
	for child in scene_tabs.get_children():
		scene_tabs.remove_child(child)
		child.queue_free()
	scene_tabs.add_child(_label("Scenes:", FONT_SIZE, Color(0.85, 0.87, 0.9)))
	for beat_name in _scenes:
		var button := _button(scene_title(beat_name), select_scene.bind(beat_name))
		button.set_meta("scene", beat_name)
		var chosen := beat_name == current_scene
		var style := _flat(Color(0.32, 0.36, 0.45) if chosen else Color(0.2, 0.22, 0.27), 8)
		if chosen:
			style.border_color = Color.WHITE
			style.set_border_width_all(2)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		scene_tabs.add_child(button)
	scene_tabs.add_child(_button("+ Scene", add_scene))


## The scene buttons, in story order.
func get_scene_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in scene_tabs.get_children():
		if child.has_meta("scene"):
			result.append(child)
	return result


# --- Palette --------------------------------------------------------------

func _build_palette() -> void:
	palette = VBoxContainer.new()
	palette.custom_minimum_size.x = PALETTE_WIDTH
	palette.add_theme_constant_override("separation", 8)
	add_child(palette)
	var groups := GridContainer.new()
	groups.columns = 2
	groups.add_theme_constant_override("h_separation", 6)
	groups.add_theme_constant_override("v_separation", 6)
	palette.add_child(groups)
	for group in StoryBlocks.GROUPS:
		var button := Button.new()
		button.text = StoryBlocks.GROUPS[group]["title"]
		button.custom_minimum_size = Vector2(PALETTE_WIDTH / 2.0 - 4, TOUCH_SIZE)
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.pressed.connect(show_group.bind(group))
		_group_buttons[group] = button
		groups.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette.add_child(scroll)
	_palette_blocks = VBoxContainer.new()
	_palette_blocks.add_theme_constant_override("separation", 8)
	scroll.add_child(_palette_blocks)
	show_group(current_group)


## Shows the blocks of [param group] in the palette.
func show_group(group: String) -> void:
	current_group = group
	if _palette_blocks == null:
		return
	for child in _palette_blocks.get_children():
		_palette_blocks.remove_child(child)
		child.queue_free()
	for type in StoryBlocks.TYPES:
		if StoryBlocks.group_of(type) == group and (type != "code" or show_code_blocks):
			_palette_blocks.add_child(_palette_block(type))
	for other in _group_buttons:
		var color: Color = StoryBlocks.GROUPS[other]["color"]
		var style := _flat(color if other == group else color.darkened(0.45), 8)
		if other == group:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
		for state in ["normal", "hover", "pressed", "focus"]:
			_group_buttons[other].add_theme_stylebox_override(state, style)


## Palette blocks of the shown group.
func get_palette_blocks() -> Array[Control]:
	var result: Array[Control] = []
	for child in _palette_blocks.get_children():
		if child.has_meta("new_type"):
			result.append(child)
	return result


func _palette_block(type: String) -> Control:
	var block := StoryBlocks.new_block(type)
	var panel := _block_panel(type, false)
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.set_meta("new_type", type)
	panel.gui_input.connect(_on_block_input.bind(panel))
	panel.add_child(_summary(block, true))
	return panel


# --- Blocks ---------------------------------------------------------------

## Rebuilds the blocks of the chosen scene from [member doc].
func rebuild() -> void:
	var scrolled := _scroll.scroll_vertical
	for child in stack.get_children():
		stack.remove_child(child)
		child.queue_free()
	_lanes.clear()
	var beat := doc.find_beat(current_scene) if doc != null else null
	if beat == null:
		stack.add_child(_label("Tap + Scene to start your story.", FONT_SIZE, Color(0.85, 0.87, 0.9)))
		return
	if doc.has_errors():
		var warning := _label("Part of this story has a mistake in its text. The gray Code blocks show where.", FONT_SIZE - 2, Color(1, 0.7, 0.5))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(warning)
	_add_lane(stack, beat, TaleCard.build(beat, _scenes), "Drag blocks here")
	if is_inside_tree():
		_scroll.set_deferred("scroll_vertical", scrolled)


func _add_lane(box: VBoxContainer, parent: TaleNode, cards: Array, hint: String) -> void:
	var lane := _lanes.size()
	_lanes.append({"parent": parent, "cards": cards, "box": box})
	for i in cards.size():
		box.add_child(_make_block(StoryBlocks.describe(cards[i], source), cards[i], lane, i))
	if cards.is_empty():
		var label := _label(hint, FONT_SIZE - 4, Color(1, 1, 1, 0.6))
		label.custom_minimum_size.y = TOUCH_SIZE - 8
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(label)


## Block controls of the chosen scene in order, nested blocks included.
func get_blocks() -> Array[Control]:
	var result: Array[Control] = []
	for control in stack.find_children("*", "PanelContainer", true, false):
		if control.has_meta("card"):
			result.append(control)
	return result


## The block control whose statement starts on [param line], or null.
func block_at_line(line: int) -> Control:
	for block in get_blocks():
		if (block.get_meta("card") as TaleCard).node.line_start == line:
			return block
	return null


## Number of block lists on screen: the scene's, then one per arm.
func lane_count() -> int:
	return _lanes.size()


## The lane that holds arm [param arm] of the wrapped [param control].
func arm_lane(control: Control, arm: int) -> int:
	var node: TaleNode = control.get_meta("block")["arms"][arm]["node"]
	for i in _lanes.size():
		if _lanes[i]["parent"] == node:
			return i
	return -1


func _make_block(block: Dictionary, card: TaleCard, lane: int, index: int) -> Control:
	var type: String = block["type"]
	var panel := _block_panel(type, card.node.line_start == _selected_line)
	panel.set_meta("block", block)
	panel.set_meta("card", card)
	panel.set_meta("lane", lane)
	panel.set_meta("index", index)
	panel.gui_input.connect(_on_block_input.bind(panel))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	if type == "choice":
		column.add_child(_words_row("Choice", {}, "", null))
		var arms: Array = block["arms"]
		for i in arms.size():
			var arm: Dictionary = arms[i]
			var row := _words_row("{text}", {"text": arm["text"]}, "arm:%d:" % i, panel)
			if not str(arm.get("condition", "")).is_empty():
				row.add_child(_label("only when " + arm["condition"], FONT_SIZE - 4, Color(1, 1, 1, 0.8)))
			if arms.size() > 1:
				row.add_child(_small_button("✕", remove_arm.bind(panel, i)))
			column.add_child(row)
			column.add_child(_arm_box(arm))
		column.add_child(_small_button("+ Option", add_arm.bind(panel, "option")))
	elif type == "if":
		var arms: Array = block["arms"]
		for i in arms.size():
			var arm: Dictionary = arms[i]
			var words: String = ARM_WORDS[arm["keyword"]]
			if arm["keyword"] != "else":
				words += " " + TEST_WORDS[arm["test"]]
			var row := _words_row(words, arm.get("fields", {}), "arm:%d:" % i, panel)
			if i > 0:
				row.add_child(_small_button("✕", remove_arm.bind(panel, i)))
			column.add_child(row)
			column.add_child(_arm_box(arm))
		var buttons := HBoxContainer.new()
		buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buttons.add_child(_small_button("+ Or if", add_arm.bind(panel, "elif")))
		if arms.back()["keyword"] != "else":
			buttons.add_child(_small_button("+ Otherwise", add_arm.bind(panel, "else")))
		column.add_child(buttons)
	else:
		column.add_child(_words_row(StoryBlocks.TYPES[type]["words"], block["fields"], "field:", panel))
	return panel


## The inside of one arm: an indented list of blocks.
func _arm_box(arm: Dictionary) -> Control:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	var inner := PanelContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _flat(Color(0, 0, 0, 0.2), 6)
	style.set_content_margin_all(6)
	inner.add_theme_stylebox_override("panel", style)
	margin.add_child(inner)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(200, TOUCH_SIZE - 8)
	box.add_theme_constant_override("separation", 6)
	inner.add_child(box)
	_add_lane(box, arm["node"], arm["cards"], "Drag blocks here")
	return margin


## The block's first row of words, without chips to tap, for the palette
## and for a block being dragged.
func _summary(block: Dictionary, wrap: bool) -> Control:
	var type: String = block["type"]
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if type == "if":
		var arm: Dictionary = block["arms"][0]
		column.add_child(_words_row("If " + TEST_WORDS[arm["test"]], arm["fields"], "", null, wrap))
	else:
		column.add_child(_words_row(StoryBlocks.TYPES[type]["words"], block["fields"], "", null, wrap))
	if StoryBlocks.shape_of(type) == "wrap":
		var gap := ColorRect.new()
		gap.color = Color(0, 0, 0, 0.2)
		gap.custom_minimum_size = Vector2(120, 14)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_child(gap)
		column.add_child(margin)
	return column


## A row of words with a chip for each field in braces. Tapping a chip
## edits the field of [param target]; without a target the chips only show.
## With [param wrap] the row wraps to the width it is given.
func _words_row(words: String, fields: Dictionary, key_prefix: String, target: Control, wrap := true) -> Container:
	var row: Container = HFlowContainer.new() if wrap else HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.y = TOUCH_SIZE
	if wrap:
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 4)
	else:
		row.add_theme_constant_override("separation", 6)
	var at := 0
	for found in RegEx.create_from_string("\\{(\\w+)\\}").search_all(words):
		_add_words(row, words.substr(at, found.get_start() - at))
		var field := found.get_string(1)
		row.add_child(_chip(field, str(fields.get(field, "")), key_prefix + field, target))
		at = found.get_end()
	_add_words(row, words.substr(at))
	return row


## Adds [param words] to [param row] one word at a time, so a row can wrap
## between them.
func _add_words(row: Container, words: String) -> void:
	for word in words.strip_edges().split(" ", false):
		var label := _label(word, FONT_SIZE, Color.WHITE)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size.y = TOUCH_SIZE - 4
		row.add_child(label)


func _chip(field: String, value: String, key: String, target: Control) -> Control:
	var text := field_text(field, value)
	var style := _flat(Color(1, 1, 1, 0.92), 14)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	var ink := Color(0.15, 0.15, 0.2) if not value.is_empty() else Color(0.45, 0.45, 0.5)
	if target == null:
		var label := _label(text, FONT_SIZE, ink)
		label.add_theme_stylebox_override("normal", style)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return label
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = TOUCH_SIZE - 4
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, ink)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	if field == "code" or field == "condition":
		var mono := SystemFont.new()
		mono.font_names = PackedStringArray(["monospace"])
		button.add_theme_font_override("font", mono)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("field_key", key)
	button.pressed.connect(edit_field.bind(target, key))
	# Chips cover most of a block, so dragging a chip drags its block.
	button.gui_input.connect(_on_block_input.bind(target, false))
	return button


## How [param value] of [param field] shows on a block.
static func field_text(field: String, value: String) -> String:
	if value.is_empty():
		return FIELD_HINTS.get(field, "…")
	match field:
		"position":
			return StoryBlocks.POSITIONS.get(value, value)
		"comparison":
			return StoryBlocks.COMPARISONS.get(value, value)
		"motion":
			return StoryBlocks.MOTIONS.get(value, value)
		"weather":
			return StoryBlocks.WEATHERS.get(value, value)
		"scene":
			return scene_title(value)
		"text", "prompt":
			return "“%s”" % (value if value.length() <= 32 else value.left(30) + "…")
	return value


func _block_panel(type: String, selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.add_theme_stylebox_override("panel", _block_style(type, selected))
	return panel


func _block_style(type: String, selected: bool) -> StyleBoxFlat:
	var color := StoryBlocks.color_of(type)
	var style := _flat(color, 10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.border_color = Color.WHITE if selected else color.darkened(0.3)
	style.set_border_width_all(3 if selected else 2)
	if StoryBlocks.shape_of(type) == "cap":
		# Nothing goes under a cap, so its bottom is flat and heavy.
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2
		style.border_width_bottom = 6
	return style


# --- Choosing a block -----------------------------------------------------

## Marks [param control] as the chosen block and reports its line.
func select_block(control: Control) -> void:
	var card: TaleCard = control.get_meta("card")
	_selected_line = card.node.line_start
	for block in get_blocks():
		var line: int = (block.get_meta("card") as TaleCard).node.line_start
		block.add_theme_stylebox_override("panel", _block_style(block.get_meta("block")["type"], line == _selected_line))
	block_selected.emit(_selected_line)


func get_selected_line() -> int:
	return _selected_line


# --- Changing blocks ------------------------------------------------------

## Adds a new block of [param type] at [param index] of block list
## [param lane]. [param fields] replace its starting values. A Code block
## without code asks for it first.
func add_block(type: String, lane: int, index: int, fields := {}) -> bool:
	var block := StoryBlocks.new_block(type)
	block["fields"].merge(fields, true)
	if type == "code" and str(block["fields"]["code"]).strip_edges().is_empty():
		ask_text(FIELD_QUESTIONS["code"], "", true, func(text: String) -> void:
			if not text.strip_edges().is_empty():
				add_block(type, lane, index, {"code": text}))
		return false
	_fill_new_block(block)
	var info: Dictionary = _lanes[lane]
	var cards: Array = info["cards"]
	var text := StoryBlocks.new_text(block, TaleEdit.indent_unit(doc))
	var new_source := TaleEdit.insert_before(source, cards[index].nodes[0], text) if index < cards.size() \
		else TaleEdit.append_to(source, doc, info["parent"], text)
	return commit(_declare_for(new_source, block))


## Moves the block [param control] to [param index] of block list
## [param lane], counting places before the move.
func move_block(control: Control, lane: int, index: int) -> bool:
	var card: TaleCard = control.get_meta("card")
	if lane == control.get_meta("lane") and (index == control.get_meta("index") or index == control.get_meta("index") + 1):
		return false
	var info: Dictionary = _lanes[lane]
	if control.is_ancestor_of(info["box"]):
		return false
	var cards: Array = info["cards"]
	var anchor: TaleNode = cards[index].nodes[0] if index < cards.size() else null
	var siblings := TaleEdit.content_children(info["parent"])
	for node in card.nodes:
		siblings.erase(node)
	var place := siblings.find(anchor) if anchor != null else siblings.size()
	return commit(TaleEdit.move_group(source, doc, card.nodes, info["parent"], place))


func delete_block(control: Control) -> bool:
	var card: TaleCard = control.get_meta("card")
	return commit(TaleEdit.delete_group(source, doc, card.nodes))


## Puts a copy of [param control] right under it. Blocks that close a
## stack are not copied, since nothing can follow them.
func duplicate_block(control: Control) -> bool:
	var card: TaleCard = control.get_meta("card")
	if StoryBlocks.shape_of(control.get_meta("block")["type"]) == "cap":
		return false
	return commit(TaleEdit.insert_after(source, card.nodes.back(), TaleEdit.group_text(source, card.nodes)))


## The value of field [param key] of [param control] ("field:name", or
## "arm:i:name" for arm i).
func field_value(control: Control, key: String) -> String:
	var block: Dictionary = control.get_meta("block")
	if key.begins_with("arm:"):
		var arm: Dictionary = block["arms"][int(key.get_slice(":", 1))]
		var field := key.get_slice(":", 2)
		return str(arm[field]) if arm.has("text") else str(arm["fields"][field])
	return str(block["fields"][key.get_slice(":", 1)])


## Edits field [param key] of [param control]. Positions, comparisons,
## motions, and weather move to their next choice; other fields ask for a
## new value.
func edit_field(control: Control, key: String) -> void:
	var field := key.get_slice(":", key.get_slice_count(":") - 1)
	var value := field_value(control, key)
	if field in CYCLE_FIELDS:
		var choices: Array = CYCLE_FIELDS[field].keys()
		set_field(control, key, choices[(choices.find(value) + 1) % choices.size()])
		return
	var type: String = control.get_meta("block")["type"]
	var question: String = _DIALOG_TITLES.get(type, FIELD_QUESTIONS.get(field, field.capitalize()))
	ask_text(question, value, field == "code", func(text: String) -> void: set_field(control, key, text))


## Sets field [param key] of [param control] to [param value] and rewrites
## its line. A Code block set to nothing is deleted.
func set_field(control: Control, key: String, value: String) -> bool:
	var block: Dictionary = control.get_meta("block")
	var card: TaleCard = control.get_meta("card")
	if key.begins_with("arm:"):
		var arm: Dictionary = block["arms"][int(key.get_slice(":", 1))]
		var field := key.get_slice(":", 2)
		if arm.has("text"):
			arm[field] = value
		else:
			arm["fields"][field] = value
		return commit(_declare_for(TaleEdit.set_statement(source, arm["node"], StoryBlocks.arm_line(arm)), block))
	if block["type"] == "code":
		return commit(_replace_card(card, value))
	block["fields"][key.get_slice(":", 1)] = value
	return commit(_declare_for(TaleEdit.set_statement(source, card.node, StoryBlocks.line_for(block)), block))


## Adds an arm to the Choice or If [param control]: "option", "elif", or
## "else".
func add_arm(control: Control, kind: String) -> bool:
	var arms: Array = control.get_meta("block")["arms"]
	var unit := TaleEdit.indent_unit(doc)
	var last: TaleNode = arms.back()["node"]
	match kind:
		"option":
			return commit(TaleEdit.insert_after(source, last, TaleWriter.option("Another option") + "\n" + unit + "pass"))
		"else":
			if arms.back()["keyword"] == "else":
				return false
			return commit(TaleEdit.insert_after(source, last, "else:\n" + unit + "pass"))
		"elif":
			var arm := {"keyword": "elif", "test": "compare", "fields": {"number": suggest("number"), "comparison": ">=", "value": "1"}}
			var text := StoryBlocks.arm_line(arm) + "\n" + unit + "pass"
			var new_source := TaleEdit.insert_before(source, last, text) if arms.back()["keyword"] == "else" \
				else TaleEdit.insert_after(source, last, text)
			return commit(_declare_for(new_source, {"type": "if", "arms": [arm]}))
	return false


## Removes arm [param arm] and its blocks. A Choice keeps at least one
## option, and the first arm of an If stays.
func remove_arm(control: Control, arm: int) -> bool:
	var block: Dictionary = control.get_meta("block")
	if arm == 0 and (block["type"] == "if" or block["arms"].size() <= 1):
		return false
	return commit(TaleEdit.delete(source, doc, block["arms"][arm]["node"]))


func _replace_card(card: TaleCard, text: String) -> String:
	if text.strip_edges().is_empty():
		return TaleEdit.delete_group(source, doc, card.nodes)
	var span := TaleEdit.group_span(card.nodes)
	var lines := PackedStringArray()
	for line in text.split("\n"):
		lines.append(card.nodes[0].indent + line if not line.strip_edges().is_empty() else "")
	return TaleEdit.replace_lines(source, span.x, span.y, lines)


# --- Starting values ------------------------------------------------------

## A value for [param field] of a new block: the story's first character,
## its first number, or another scene.
func suggest(field: String) -> String:
	match field:
		"character":
			var used := _characters_in_tale()
			if not used.is_empty():
				return used[0]
			var cast := cast_ids()
			return cast[0] if not cast.is_empty() else "someone"
		"number":
			for statement in doc.statements:
				if statement.kind == TaleNode.Kind.VAR and statement.expr != null and statement.expr.kind == TaleExpr.Kind.LITERAL \
						and (statement.expr.value is int or statement.expr.value is float):
					return statement.name
			return "score"
		"scene":
			for beat_name in _scenes:
				if beat_name != current_scene:
					return beat_name
			return current_scene
	return ""


## Ids of the story's characters, from its cast folder.
func cast_ids() -> PackedStringArray:
	if _cast == null:
		var ids: Array = StoryStage.scan_cast(config.cast_folder).keys() if config != null else []
		ids.sort()
		_cast = PackedStringArray(ids)
	return _cast


## Characters who speak or are shown in the tale, in order of first use.
func _characters_in_tale() -> PackedStringArray:
	var result := PackedStringArray()
	var pending: Array = doc.statements.duplicate()
	pending.reverse()
	while not pending.is_empty():
		var node: TaleNode = pending.pop_back()
		var children := node.body.duplicate()
		children.reverse()
		pending.append_array(children)
		var found := ""
		if node.kind == TaleNode.Kind.DIALOGUE:
			found = node.name
		elif node.kind == TaleNode.Kind.EXPRESSION:
			var expr := node.expr.operands[0] if node.expr.kind == TaleExpr.Kind.AWAIT else node.expr
			if expr.kind == TaleExpr.Kind.CALL and expr.operands[0].kind == TaleExpr.Kind.ATTRIBUTE \
					and expr.operands[0].name == "enter" and expr.operands[0].operands[0].kind == TaleExpr.Kind.IDENTIFIER:
				found = expr.operands[0].operands[0].name
		if not found.is_empty() and found not in result:
			result.append(found)
	return result


func _fill_new_block(block: Dictionary) -> void:
	for field in block["fields"]:
		if str(block["fields"][field]).is_empty() and field in ["character", "number", "scene"]:
			block["fields"][field] = suggest(field)
	if block["type"] == "if":
		block["arms"][0]["fields"]["number"] = suggest("number")


## [param text] with a [code]var[/code] line for each number or name
## [param block] uses that the tale does not declare yet.
func _declare_for(text: String, block: Dictionary) -> String:
	var names := {}
	match block["type"]:
		"set", "add", "take":
			names[block["fields"]["number"]] = "0"
		"ask_name":
			names[block["fields"]["word"]] = "\"\""
		"if":
			for arm in block["arms"]:
				if arm.get("test", "") == "compare":
					names[arm["fields"]["number"]] = "0"
	for var_name in names:
		text = declare(text, var_name, names[var_name])
	return text


## [param text] with [code]var name := value[/code] added after the tale's
## other variables, unless [param var_name] is declared already or is not a
## plain name.
static func declare(text: String, var_name: String, value: String) -> String:
	if not var_name.is_valid_identifier():
		return text
	var parsed := TaleParser.parse(text)
	var last: TaleNode = null
	var first_beat: TaleNode = null
	for statement in parsed.statements:
		if statement.kind == TaleNode.Kind.VAR or statement.kind == TaleNode.Kind.CONST:
			if statement.name == var_name:
				return text
			last = statement
		elif statement.kind == TaleNode.Kind.BEAT and first_beat == null:
			first_beat = statement
	var line := "var %s := %s" % [var_name, value]
	if last != null:
		return TaleEdit.insert_after(text, last, line)
	if first_beat != null:
		return TaleEdit.insert_before(text, first_beat, line + "\n")
	return line + "\n\n" + text


# --- Dragging -------------------------------------------------------------

## Follows a press on [param control]. A press on a field chip
## ([param own] false) is left for the chip too, so a tap still edits it.
func _on_block_input(event: InputEvent, control: Control, own := true) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pressing = control
		_press_at = event.global_position
		_press_time = 0.0
		_from_chip = not own
		if own:
			accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _drag.is_empty() and _pressing == control and event.global_position.distance_to(_press_at) > DRAG_DISTANCE:
			start_drag(control, event.global_position)


# Once a drag starts, the finger may leave the block, so the rest of the
# drag is followed here instead of through the block's own input.
func _input(event: InputEvent) -> void:
	if _drag.is_empty() and _pressing == null and not _swallow_release:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _swallow_release:
			# The press opened the long-press menu; the chip under it stays as it is.
			_swallow_release = false
			get_viewport().set_input_as_handled()
		elif not _drag.is_empty():
			drop(event.global_position)
			get_viewport().set_input_as_handled()
		elif _pressing != null:
			var tapped := _pressing
			_pressing = null
			if not _from_chip:
				_tap(tapped)
	elif event is InputEventMouseMotion and not _drag.is_empty():
		move_drag(event.global_position)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pressing != null and _drag.is_empty():
		_press_time += delta
		if _press_time >= LONG_PRESS_TIME and is_instance_valid(_pressing):
			var control := _pressing
			_pressing = null
			if control.has_meta("card"):
				_swallow_release = true
				open_block_menu(control)
	elif not _drag.is_empty():
		var at: Vector2 = _drag["at"]
		var rect := _scroll.get_global_rect()
		if rect.has_point(at):
			if at.y < rect.position.y + TOUCH_SIZE:
				_scroll.scroll_vertical -= int(600 * delta)
			elif at.y > rect.end.y - TOUCH_SIZE:
				_scroll.scroll_vertical += int(600 * delta)


## A tap on a scene block chooses it; a tap on a palette block adds it under
## the chosen block, or at the end of the scene.
func _tap(control: Control) -> void:
	if control.has_meta("card"):
		select_block(control)
		return
	var type: String = control.get_meta("new_type")
	var lane := 0
	var index := -1
	var selected := block_at_line(_selected_line)
	if selected != null:
		lane = selected.get_meta("lane")
		index = selected.get_meta("index") + 1
	if _lanes.is_empty():
		show_message("Add a scene first.")
		return
	index = allowed_index(lane, _lane_blocks(lane).size() if index < 0 else index, type, null)
	if index < 0:
		show_message("Nothing can go after Go to scene or The end.")
		return
	add_block(type, lane, index)


## Starts dragging [param control]: a block of the scene, or a copy of a
## palette block.
func start_drag(control: Control, at: Vector2) -> void:
	_pressing = null
	_drag = {"control": control, "offset": Vector2(24, 22), "at": at}
	var block: Dictionary = control.get_meta("block") if control.has_meta("card") else StoryBlocks.new_block(control.get_meta("new_type"))
	if control.has_meta("card"):
		control.modulate.a = 0.35
	_ghost = _block_panel(block["type"], false)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.add_child(_summary(block, false))
	_ghost.top_level = true
	_ghost.z_index = 20
	_ghost.modulate.a = 0.85
	add_child(_ghost)
	move_drag(at)


func move_drag(at: Vector2) -> void:
	_drag["at"] = at
	_ghost.global_position = at - _drag["offset"]
	_update_target(at)


## Ends the drag at [param at]: the block lands at the drop line, or is
## deleted when it is over the palette.
func drop(at: Vector2) -> void:
	if _drag.is_empty():
		return
	_update_target(at)
	var control: Control = _drag["control"]
	var target := _target
	_end_drag()
	if target.get("delete", false):
		delete_block(control)
	elif target.has("lane"):
		if control.has_meta("card"):
			move_block(control, target["lane"], target["index"])
		else:
			add_block(control.get_meta("new_type"), target["lane"], target["index"])


func is_dragging() -> bool:
	return not _drag.is_empty()


## Where the dragged block would land now.
func get_drop_target() -> Dictionary:
	return _target


func _end_drag() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	var control: Control = _drag.get("control")
	if is_instance_valid(control) and control.has_meta("card"):
		control.modulate.a = 1.0
	_drag = {}
	_target = {}
	_drop_line.visible = false


func _update_target(at: Vector2) -> void:
	_target = {}
	_drop_line.visible = false
	var control: Control = _drag["control"]
	var moving := control.has_meta("card")
	if palette.get_global_rect().has_point(at):
		if moving:
			_target = {"delete": true}
			_ghost.modulate = Color(1, 0.55, 0.55, 0.85)
		return
	_ghost.modulate = Color(1, 1, 1, 0.85)
	if _lanes.is_empty() or not _scroll.get_global_rect().grow(TOUCH_SIZE / 2.0).has_point(at):
		return
	var lane := 0
	for i in range(_lanes.size() - 1, 0, -1):
		var box: Control = _lanes[i]["box"]
		if moving and control.is_ancestor_of(box):
			continue
		var rect := box.get_global_rect()
		if at.y >= rect.position.y - 8 and at.y <= rect.end.y + 8 and at.x >= rect.position.x - 16:
			lane = i
			break
	var blocks := _lane_blocks(lane)
	var index := blocks.size()
	for block in blocks:
		if at.y < block.get_global_rect().get_center().y:
			index = block.get_meta("index")
			break
	var type: String = control.get_meta("block")["type"] if moving else control.get_meta("new_type")
	index = allowed_index(lane, index, type, control if moving else null)
	if index < 0:
		return
	_target = {"lane": lane, "index": index}
	_show_drop_line(lane, index)


## Where a block of [param type] may go in block list [param lane], near
## [param index]: nothing goes after Go to scene or The end, and those go
## only at the end of a list that has neither. -1 when it can't go there.
func allowed_index(lane: int, index: int, type: String, moving: Control) -> int:
	var blocks := _lane_blocks(lane)
	var cap := -1
	for block in blocks:
		if block != moving and StoryBlocks.shape_of(block.get_meta("block")["type"]) == "cap":
			cap = block.get_meta("index")
			break
	if StoryBlocks.shape_of(type) == "cap":
		return -1 if cap >= 0 else blocks.size()
	return mini(index, cap) if cap >= 0 else index


func _lane_blocks(lane: int) -> Array[Control]:
	var result: Array[Control] = []
	for child in (_lanes[lane]["box"] as Control).get_children():
		if child.has_meta("card"):
			result.append(child)
	return result


func _show_drop_line(lane: int, index: int) -> void:
	var box: Control = _lanes[lane]["box"]
	var blocks := _lane_blocks(lane)
	var y := box.global_position.y + 2
	if index < blocks.size():
		y = blocks[index].global_position.y - 4
	elif not blocks.is_empty():
		y = blocks.back().get_global_rect().end.y + 1
	_drop_line.global_position = Vector2(box.global_position.x, y)
	_drop_line.size = Vector2(maxf(box.size.x, 200), 5)
	_drop_line.visible = true


# --- Menus and typing -----------------------------------------------------

## The long-press menu of [param control]: Duplicate and Delete.
func open_block_menu(control: Control) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	menu.add_item("Duplicate", 0)
	menu.add_item("Delete", 1)
	menu.set_item_disabled(0, StoryBlocks.shape_of(control.get_meta("block")["type"]) == "cap")
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			duplicate_block(control)
		else:
			delete_block(control))
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(Vector2i(control.global_position + Vector2(0, control.size.y)), Vector2i.ZERO))
	return menu


## Asks for text over the editor, then calls [param on_done] with it.
## Cancel leaves everything as it was.
func ask_text(question: String, value: String, multiline: bool, on_done: Callable) -> Control:
	close_dialog()
	_dialog = Control.new()
	_dialog.top_level = true
	_dialog.z_index = 30
	_dialog.size = get_viewport_rect().size if is_inside_tree() else Vector2(1024, 768)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)
	var panel := PanelContainer.new()
	var style := _flat(Color(0.16, 0.17, 0.21), 12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_label(question, FONT_SIZE + 2, Color.WHITE))
	var edit: Control
	if multiline:
		var text_edit := TextEdit.new()
		text_edit.text = value
		text_edit.custom_minimum_size = Vector2(520, 220)
		edit = text_edit
	else:
		var line_edit := LineEdit.new()
		line_edit.text = value
		line_edit.custom_minimum_size = Vector2(520, TOUCH_SIZE)
		line_edit.select_all_on_focus = true
		edit = line_edit
	edit.add_theme_font_size_override("font_size", FONT_SIZE)
	edit.set_meta("field_key", "dialog:text")
	column.add_child(edit)
	var done := func() -> void:
		var text: String = edit.text
		close_dialog()
		on_done.call(text)
	if edit is LineEdit:
		edit.text_submitted.connect(func(_text: String) -> void: done.call())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	buttons.add_child(_button("Cancel", close_dialog))
	buttons.add_child(_button("OK", done))
	add_child(_dialog)
	(func() -> void:
		if is_instance_valid(edit) and edit.is_inside_tree():
			edit.grab_focus()).call_deferred()
	return _dialog


func close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null


func get_dialog() -> Control:
	return _dialog


# --- Small controls -------------------------------------------------------

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(TOUCH_SIZE * 2, TOUCH_SIZE)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(on_press)
	return button


func _small_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(TOUCH_SIZE, TOUCH_SIZE - 4)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	button.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0.22), 8))
	button.add_theme_stylebox_override("hover", _flat(Color(0, 0, 0, 0.3), 8))
	button.add_theme_stylebox_override("pressed", _flat(Color(0, 0, 0, 0.4), 8))
	button.pressed.connect(on_press)
	return button


static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style

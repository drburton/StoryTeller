class_name StudioSceneMap
extends Control
## The map of scenes (docs/studio-design.md §4): every scene of the story as
## a box, with arrows for each Go to scene and each option of a Choice. Tap
## a scene to open it in the blocks; drag to look around. A scene nothing
## leads to, and a Go to scene whose scene is gone, are marked, as the
## Story Map marks them in the plugin.

## Emitted when the student taps a scene.
signal scene_chosen(beat_name: String)
## Emitted when the student closes the map.
signal closed

const BOX_WIDTH := 250.0
const COLUMN_WIDTH := 340.0
const ROW_HEIGHT := 30.0
const MARGIN := 40.0
const GAP := 36.0
const PADDING := 12.0
const START_COLOR := Color(0.3, 0.7, 0.4)
const CHOICE_COLOR := Color(0.95, 0.6, 0.25)
const PROBLEM_COLOR := Color(1.0, 0.75, 0.35)
const ARROW_COLOR := Color(0.75, 0.8, 0.9, 0.8)

var graph: StoryGraph
var tale_name := ""
var current_scene := ""
var _scroll: ScrollContainer
var _canvas: Control
var _boxes := {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = StudioUI.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	column.add_child(bar)
	var title := StudioUI.label("Map of scenes", StudioUI.FONT_SIZE + 6)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	bar.add_child(StudioUI.label("Tap a scene to open it.", StudioUI.FONT_SIZE - 4, Color(0.75, 0.78, 0.85)))
	bar.add_child(StudioUI.button("✕ Close", close))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_canvas = Control.new()
	_canvas.draw.connect(_draw_arrows)
	_canvas.gui_input.connect(_on_canvas_input)
	_scroll.add_child(_canvas)


## Shows the scenes of [param doc], the tale [param tale], with
## [param current] marked as the scene open in the blocks.
func show_story(doc: TaleDocument, tale: String, current := "") -> void:
	tale_name = tale
	current_scene = current
	graph = StoryGraph.build({tale: doc}, tale, "start")
	for box in _boxes.values():
		_canvas.remove_child(box)
		box.queue_free()
	_boxes.clear()
	# The layout gives each scene its column; boxes in a column are then
	# stacked by their own height, since choices wrap onto more lines.
	var positions := graph.layout(PackedStringArray([tale]), COLUMN_WIDTH, ROW_HEIGHT, 36.0)
	var columns := {}
	for id in graph.beats:
		var box := _make_box(id)
		_canvas.add_child(box)
		_boxes[graph.beats[id]["beat"]] = box
		var at: Vector2 = positions.get(id, Vector2.ZERO)
		if not columns.has(at.x):
			columns[at.x] = []
		columns[at.x].append([at.y, box])
	var bounds := Vector2.ZERO
	for x in columns:
		var stacked: Array = columns[x]
		stacked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var top := MARGIN
		for entry in stacked:
			var box: Button = entry[1]
			box.position = Vector2(x + MARGIN, top)
			top += box.custom_minimum_size.y + GAP
			bounds = bounds.max(box.position + box.custom_minimum_size)
	_canvas.custom_minimum_size = bounds + Vector2(MARGIN, MARGIN)
	_canvas.queue_redraw()


## The box of the scene [param beat_name], or null.
func get_box(beat_name: String) -> Button:
	return _boxes.get(beat_name)


func get_scenes() -> PackedStringArray:
	return PackedStringArray(_boxes.keys())


## The words in the box of [param beat_name], one string per row.
func box_rows(beat_name: String) -> PackedStringArray:
	var rows := PackedStringArray()
	var box := get_box(beat_name)
	if box != null:
		for label in box.find_children("*", "Label", true, false):
			rows.append(label.text)
	return rows


## Opens the scene [param beat_name] and closes the map.
func choose(beat_name: String) -> void:
	scene_chosen.emit(beat_name)
	close()


func close() -> void:
	closed.emit()
	queue_free()


func _make_box(id: String) -> Button:
	var info: Dictionary = graph.beats[id]
	var beat_name: String = info["beat"]
	var rows: Array = []
	if id in graph.entries:
		rows.append(["▶ The story starts here", START_COLOR])
	for exit in info["exits"]:
		if exit["kind"] == "choice":
			rows.append(["“%s” → %s" % [exit["label"], _title(exit["to"])], CHOICE_COLOR])
	for problem in graph.missing:
		if problem["from"] == id:
			rows.append(["⚠ Goes to a scene that isn't there: %s" % _title(problem["to"]), PROBLEM_COLOR])
	if id in graph.unreachable:
		rows.append(["⚠ No way to get here yet", PROBLEM_COLOR])
	if info["ends"]:
		rows.append(["■ The story can end here", Color(0.7, 0.73, 0.8)])
	var box := Button.new()
	box.set_meta("scene", beat_name)
	box.focus_mode = Control.FOCUS_NONE
	var chosen := beat_name == current_scene
	var style := StudioUI.flat(Color(0.2, 0.22, 0.27), 10)
	style.set_border_width_all(3 if chosen else 2)
	style.border_color = Color.WHITE if chosen else (PROBLEM_COLOR if id in graph.unreachable else Color(0.35, 0.4, 0.5))
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.31, 0.38)
	for state in ["normal", "hover", "focus"]:
		box.add_theme_stylebox_override(state, style)
	box.add_theme_stylebox_override("pressed", pressed)
	box.pressed.connect(choose.bind(beat_name))
	var width := BOX_WIDTH - PADDING * 2
	var height := PADDING * 2
	var lines: Array = [[StudioBlockEditor.scene_title(beat_name), StudioUI.FONT_SIZE, Color.WHITE]]
	for row in rows:
		lines.append([row[0], StudioUI.FONT_SIZE - 6, row[1]])
	for line in lines:
		var label := StudioUI.label(line[0], line[1], line[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = Vector2(PADDING, height - PADDING)
		label.size.x = width
		var font := get_theme_font("font", "Label") if is_inside_tree() else ThemeDB.fallback_font
		var lines_size := font.get_multiline_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, width, line[1])
		label.size.y = lines_size.y
		box.add_child(label)
		height += lines_size.y + 2
	box.custom_minimum_size = Vector2(BOX_WIDTH, maxf(height, 56))
	box.size = box.custom_minimum_size
	return box


func _title(id: String) -> String:
	var beat_name := id.get_slice(".", 1) if id.get_slice(".", 0) == tale_name else id
	return StudioBlockEditor.scene_title(beat_name)


# Arrows from the right side of a scene to the left side of each scene it
# goes to, curving around when they go back.
func _draw_arrows() -> void:
	if graph == null:
		return
	for id in graph.beats:
		var from_box: Control = _boxes.get(graph.beats[id]["beat"])
		var drawn := {}
		for exit in graph.beats[id]["exits"]:
			var to: String = exit["to"]
			if not graph.beats.has(to) or drawn.has(to):
				continue
			drawn[to] = true
			var to_box: Control = _boxes.get(graph.beats[to]["beat"])
			var start := from_box.position + Vector2(from_box.custom_minimum_size.x, 28)
			var end := to_box.position + Vector2(0, 28)
			var out := Vector2(maxf(60.0, absf(end.x - start.x) * 0.4), 0)
			var into := out
			if is_equal_approx(from_box.position.x, to_box.position.x):
				# In the same column: from the bottom of one box to the top of
				# the other.
				var below := to_box.position.y > from_box.position.y
				start = from_box.position + Vector2(BOX_WIDTH / 2, from_box.custom_minimum_size.y if below else 0.0)
				end = to_box.position + Vector2(BOX_WIDTH / 2, 0.0 if below else to_box.custom_minimum_size.y)
				out = Vector2(0, 30 if below else -30)
				into = out
			var points := PackedVector2Array()
			for i in 25:
				var t := i / 24.0
				points.append(start.bezier_interpolate(start + out, end - into, end, t))
			_canvas.draw_polyline(points, ARROW_COLOR, 3.0, true)
			var direction := (end - points[-3]).normalized()
			var side := Vector2(-direction.y, direction.x)
			_canvas.draw_colored_polygon(PackedVector2Array([end, end - direction * 14 + side * 8, end - direction * 14 - side * 8]), ARROW_COLOR)


# Dragging the empty map moves it, with a mouse or a finger.
func _on_canvas_input(event: InputEvent) -> void:
	var moved := Vector2.ZERO
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		moved = event.relative
	elif event is InputEventScreenDrag:
		moved = event.relative
	if moved != Vector2.ZERO:
		_scroll.scroll_horizontal -= int(moved.x)
		_scroll.scroll_vertical -= int(moved.y)
		_canvas.accept_event()

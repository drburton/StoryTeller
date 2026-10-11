@tool
class_name StoryMapView
extends GraphEdit
## The Story Map: every beat of the tales in one folder as a node, with
## arrows for jumps, beat calls, and choice branches. Beats that nothing
## leads to, and jumps to beats that don't exist, are highlighted.
##
## Double-click a beat to edit it. Drag from a beat's right edge onto
## another beat to add a jump, or into empty space to create a new beat.
## Moved beats keep their place in a "<tale>.tale.map" file next to the tale.

## Emitted when a beat is double-clicked.
signal beat_opened(path: String, beat: String)
## Emitted with a tale's new text after a jump or beat is added on the map.
signal edit_requested(path: String, new_source: String)

const TALE_COLORS: Array[Color] = [
	Color(0.4, 0.65, 0.95), Color(0.95, 0.6, 0.35), Color(0.5, 0.8, 0.5),
	Color(0.85, 0.5, 0.8), Color(0.9, 0.8, 0.35), Color(0.45, 0.8, 0.8),
]
const UNREACHABLE_COLOR := Color(0.95, 0.65, 0.25)
const MISSING_COLOR := Color(0.95, 0.35, 0.3)

var graph: StoryGraph
## Tale name to file path, and to current text.
var paths: Dictionary = {}
var sources: Dictionary = {}

var _colors: Dictionary = {}


func _init() -> void:
	right_disconnects = false
	show_zoom_label = true
	connection_request.connect(_on_connection_request)
	connection_to_empty.connect(_on_connection_to_empty)
	end_node_move.connect(_save_positions)


## Shows the beats of [param tale_sources] (path to text).
func show_story(tale_sources: Dictionary, start_tale := "", start_beat := "start") -> void:
	paths.clear()
	sources.clear()
	var docs := {}
	var order := PackedStringArray()
	var file_paths := tale_sources.keys()
	file_paths.sort()
	for path in file_paths:
		var tale_name: String = path.get_file().get_basename()
		paths[tale_name] = path
		sources[tale_name] = tale_sources[path]
		docs[tale_name] = TaleParser.parse(tale_sources[path], path)
		order.append(tale_name)
	if start_tale in order:
		order.remove_at(order.find(start_tale))
		order.insert(0, start_tale)
	_colors.clear()
	for i in order.size():
		_colors[order[i]] = TALE_COLORS[i % TALE_COLORS.size()]
	graph = StoryGraph.build(docs, start_tale, start_beat)
	clear_connections()
	for child in get_children():
		if child is GraphNode:
			remove_child(child)
			child.queue_free()
	var positions := graph.layout(PackedStringArray([start_tale]) if start_tale in order else PackedStringArray())
	for id in positions:
		positions[id] += Vector2(40, 70)
	for tale_name in order:
		var saved := load_positions(paths[tale_name])
		for beat_name in saved:
			positions["%s.%s" % [tale_name, beat_name]] = saved[beat_name]
	for id in graph.beats:
		add_child(_make_node(id, positions.get(id, Vector2.ZERO)))
	var linked := {}
	for id in graph.beats:
		for exit in graph.beats[id]["exits"]:
			var key: String = id + ">" + exit["to"]
			if graph.beats.has(exit["to"]) and not linked.has(key):
				linked[key] = true
				connect_node(node_name(id), 0, node_name(exit["to"]), 0)


## GraphNode name for a beat id ("tale.beat" has a dot, which node names
## can't contain).
static func node_name(id: String) -> String:
	return id.replace(".", "__")


func get_beat_node(id: String) -> GraphNode:
	return get_node_or_null(NodePath(node_name(id))) as GraphNode


## Saved positions for a tale: beat name to Vector2.
static func load_positions(path: String) -> Dictionary:
	var result := {}
	var map_path := path + ".map"
	if not FileAccess.file_exists(map_path):
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	if parsed is Dictionary:
		for beat_name in parsed.get("beats", {}):
			var at: Array = parsed["beats"][beat_name]
			result[beat_name] = Vector2(at[0], at[1])
	return result


static func save_position(path: String, beat_name: String, at: Vector2) -> void:
	var map_path := path + ".map"
	var data := {"beats": {}}
	if FileAccess.file_exists(map_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(map_path))
		if parsed is Dictionary and parsed.get("beats") is Dictionary:
			data = parsed
	data["beats"][beat_name] = [snappedf(at.x, 1.0), snappedf(at.y, 1.0)]
	var file := FileAccess.open(map_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t", true) + "\n")


func _make_node(id: String, at: Vector2) -> GraphNode:
	var info: Dictionary = graph.beats[id]
	var tale: String = info["tale"]
	var node := GraphNode.new()
	node.name = node_name(id)
	node.title = info["beat"]
	node.position_offset = at
	node.tooltip_text = "%s.tale, line %d. Double-click to edit." % [tale, info["line"]]
	node.set_meta("beat_id", id)
	var color: Color = _colors.get(tale, TALE_COLORS[0])
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(180, 0)
	node.add_child(column)
	var tale_label := Label.new()
	tale_label.text = tale
	tale_label.add_theme_color_override("font_color", color)
	tale_label.add_theme_font_size_override("font_size", 12)
	column.add_child(tale_label)
	var count := Label.new()
	count.text = "%d statement%s" % [info["statements"], "" if info["statements"] == 1 else "s"]
	count.add_theme_font_size_override("font_size", 12)
	column.add_child(count)
	for exit in info["exits"]:
		if exit["kind"] == "choice":
			var label := Label.new()
			label.text = "“%s” → %s" % [exit["label"], _short(exit["to"], tale)]
			label.add_theme_font_size_override("font_size", 12)
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.custom_minimum_size = Vector2(180, 0)
			column.add_child(label)
	var problems := PackedStringArray()
	if id in graph.unreachable:
		problems.append("Nothing leads here")
	for missing in graph.missing:
		if missing["from"] == id:
			problems.append("Jumps to missing %s" % _short(missing["to"], tale))
	for problem in problems:
		var label := Label.new()
		label.text = "⚠ " + problem
		label.add_theme_color_override("font_color", MISSING_COLOR if problem.begins_with("Jumps") else UNREACHABLE_COLOR)
		label.add_theme_font_size_override("font_size", 12)
		column.add_child(label)
	if info["ends"]:
		var end := Label.new()
		end.text = "■ story can end here"
		end.add_theme_font_size_override("font_size", 12)
		end.modulate = Color(1, 1, 1, 0.6)
		column.add_child(end)
	node.set_slot(0, true, 0, color, true, 0, color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = MISSING_COLOR if not problems.is_empty() and problems[-1].begins_with("Jumps") else (UNREACHABLE_COLOR if not problems.is_empty() else color.darkened(0.3))
	style.set_content_margin_all(8)
	node.add_theme_stylebox_override("panel", style)
	var titlebar := StyleBoxFlat.new()
	titlebar.bg_color = color.darkened(0.45)
	titlebar.set_corner_radius_all(6)
	titlebar.corner_radius_bottom_left = 0
	titlebar.corner_radius_bottom_right = 0
	titlebar.set_content_margin_all(6)
	node.add_theme_stylebox_override("titlebar", titlebar)
	node.add_theme_stylebox_override("titlebar_selected", titlebar)
	node.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			open_beat(id))
	return node


## Asks the Story tab to open [param id] ("tale.beat") in the card editor.
func open_beat(id: String) -> void:
	var info: Dictionary = graph.beats[id]
	beat_opened.emit(paths[info["tale"]], info["beat"])


## Adds [code]jump to_id[/code] at the end of beat [param from_id].
func link(from_id: String, to_id: String) -> void:
	var tale: String = graph.beats[from_id]["tale"]
	var source: String = sources[tale]
	var doc := TaleParser.parse(source)
	var beat := doc.find_beat(graph.beats[from_id]["beat"])
	edit_requested.emit(paths[tale], TaleEdit.append_to(source, doc, beat, TaleWriter.jump(_short(to_id, tale))))


## Creates a new beat in [param from_id]'s tale, linked from it with a jump,
## and places it at [param at] on the map. Returns the new beat's name.
func link_to_new_beat(from_id: String, at: Vector2) -> String:
	var tale: String = graph.beats[from_id]["tale"]
	var doc := TaleParser.parse(sources[tale])
	var beat_name := "new_beat"
	var n := 2
	while doc.find_beat(beat_name) != null:
		beat_name = "new_beat_%d" % n
		n += 1
	var linked := TaleEdit.append_to(sources[tale], doc, doc.find_beat(graph.beats[from_id]["beat"]), TaleWriter.jump(beat_name))
	save_position(paths[tale], beat_name, at)
	edit_requested.emit(paths[tale], TaleEdit.add_beat(linked, TaleParser.parse(linked), beat_name))
	return beat_name


func _on_connection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	link(get_node(NodePath(from_node)).get_meta("beat_id"), get_node(NodePath(to_node)).get_meta("beat_id"))


func _on_connection_to_empty(from_node: StringName, _from_port: int, release_position: Vector2) -> void:
	link_to_new_beat(get_node(NodePath(from_node)).get_meta("beat_id"), (release_position + scroll_offset) / zoom)


func _save_positions() -> void:
	for child in get_children():
		if child is GraphNode and child.selected:
			var info: Dictionary = graph.beats[child.get_meta("beat_id")]
			save_position(paths[info["tale"]], info["beat"], child.position_offset)


## "beat" for a beat in [param tale], "tale.beat" otherwise.
static func _short(id: String, tale: String) -> String:
	return id.get_slice(".", 1) if id.get_slice(".", 0) == tale else id

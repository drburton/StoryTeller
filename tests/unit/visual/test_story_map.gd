extends "res://tests/framework/story_test.gd"
## Tests for the Story Map: the graph of beats, its problems and layout,
## and the map view's editing.

const FOLDER := "user://story_map_test"
const MAIN := """beat start:
	"Hello."
	choose:
		"Left":
			jump left
		"Right":
			jump side.right

beat left:
	helper()
	jump nowhere

beat helper:
	"Helping."

beat forgotten:
	pass
"""
const SIDE := """beat right:
	"On the right."
"""


func _docs(sources: Dictionary) -> Dictionary:
	var docs := {}
	for tale_name in sources:
		docs[tale_name] = TaleParser.parse(sources[tale_name])
	return docs


func test_graph_exits_problems_and_endings() -> void:
	var graph := StoryGraph.build(_docs({"main": MAIN, "side": SIDE}), "main")
	assert_eq(graph.beats.keys().size(), 5)
	var exits: Array = graph.beats["main.start"]["exits"]
	assert_eq(exits.map(func(exit: Dictionary) -> String: return "%s:%s:%s" % [exit["kind"], exit["label"], exit["to"]]), ["choice:Left:main.left", "choice:Right:side.right"])
	assert_eq(graph.beats["main.left"]["exits"].map(func(exit: Dictionary) -> String: return exit["kind"] + ":" + exit["to"]), ["call:main.helper", "jump:main.nowhere"])
	assert_eq(graph.missing, [{"from": "main.left", "to": "main.nowhere", "line": 11}])
	assert_eq(graph.unreachable, PackedStringArray(["main.forgotten"]))
	assert_eq(graph.entries, PackedStringArray(["main.start"]))
	assert_false(graph.beats["main.start"]["ends"], "every option jumps")
	assert_true(graph.beats["side.right"]["ends"])
	assert_eq(graph.beats["main.start"]["statements"], 6)


func test_demo_story_is_fully_connected() -> void:
	var sources := {}
	for tale_name in ["welcome", "prologue", "chapter_1"]:
		sources[tale_name] = FileAccess.get_file_as_string("res://demo/tales/%s.tale" % tale_name)
	var graph := StoryGraph.build(_docs(sources), "welcome")
	assert_eq(graph.missing, [])
	assert_eq(graph.unreachable, PackedStringArray())
	var targets: Array = graph.beats["welcome.topics"]["exits"].map(func(exit: Dictionary) -> String: return exit["to"])
	assert_has(targets, "prologue.start")
	assert_has(targets, "welcome.farewell")
	assert_has(graph.beats["prologue.walk"]["exits"].map(func(exit: Dictionary) -> String: return exit["to"]), "chapter_1.start")
	assert_true(graph.beats["chapter_1.goodbye"]["ends"])
	assert_eq(graph.entries[0], "welcome.start", "New Game's beat comes first")
	assert_eq(graph.tale_order(), PackedStringArray(["welcome", "prologue", "chapter_1"]), "tales in the order play reaches them")


func test_layout_puts_tales_in_bands_and_steps_in_columns() -> void:
	var graph := StoryGraph.build(_docs({"main": MAIN, "side": SIDE}), "main")
	var at := graph.layout(PackedStringArray(["main"]), 100.0, 50.0)
	assert_eq(graph.tale_order(), PackedStringArray(["main", "side"]))
	assert_eq(at["main.start"], Vector2(0, 0))
	assert_eq(at["main.left"].x, 100.0)
	assert_eq(at["main.helper"].x, 200.0)
	assert_true(at["main.forgotten"].x > at["main.helper"].x, "unreached beats go last")
	assert_true(at["side.right"].y > at["main.start"].y, "each tale has its own band")


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(FOLDER):
		for file_name in DirAccess.get_files_at(FOLDER):
			DirAccess.remove_absolute(FOLDER.path_join(file_name))


func before_each() -> void:
	_clean()
	_write(FOLDER.path_join("main.tale"), MAIN)
	_write(FOLDER.path_join("side.tale"), SIDE)


func after_each() -> void:
	_clean()


func test_map_view_shows_beats_and_links() -> void:
	var map: StoryMapView = track(StoryMapView.new())
	tree.root.add_child(map)
	map.show_story({FOLDER.path_join("main.tale"): MAIN, FOLDER.path_join("side.tale"): SIDE}, "main")
	await tree.process_frame
	var nodes := map.get_children().filter(func(child: Node) -> bool: return child is GraphNode)
	assert_eq(nodes.size(), 5)
	assert_eq(map.get_connection_list().size(), 3, "start to left and right, left to helper")
	var forgotten := map.get_beat_node("main.forgotten")
	assert_true(forgotten.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text.contains("Nothing leads here")))
	var opened := []
	map.beat_opened.connect(func(path: String, beat: String) -> void: opened.append([path, beat]))
	map.open_beat("side.right")
	assert_eq(opened, [[FOLDER.path_join("side.tale"), "right"]])


func test_map_view_links_and_creates_beats() -> void:
	var map: StoryMapView = track(StoryMapView.new())
	tree.root.add_child(map)
	map.show_story({FOLDER.path_join("main.tale"): MAIN, FOLDER.path_join("side.tale"): SIDE}, "main")
	var edits := []
	map.edit_requested.connect(func(path: String, text: String) -> void: edits.append([path, text]))
	map.link("side.right", "main.helper")
	assert_eq(edits[0][0], FOLDER.path_join("side.tale"))
	assert_eq(edits[0][1], "beat right:\n\t\"On the right.\"\n\tjump main.helper\n")
	var created := map.link_to_new_beat("main.helper", Vector2(400, 300))
	assert_eq(created, "new_beat")
	assert_true(edits[1][1].contains("beat helper:\n\t\"Helping.\"\n\tjump new_beat\n"))
	assert_true(edits[1][1].ends_with("beat new_beat:\n\tpass\n"))
	assert_eq(StoryMapView.load_positions(FOLDER.path_join("main.tale")), {"new_beat": Vector2(400, 300)})


func test_saved_positions_override_the_layout() -> void:
	StoryMapView.save_position(FOLDER.path_join("main.tale"), "left", Vector2(-50, 500))
	var map: StoryMapView = track(StoryMapView.new())
	tree.root.add_child(map)
	map.show_story({FOLDER.path_join("main.tale"): MAIN}, "main")
	assert_eq(map.get_beat_node("main.left").position_offset, Vector2(-50, 500))


func test_story_tab_map_view_round_trip() -> void:
	var panel: TaleEditorPanel = track(TaleEditorPanel.new())
	tree.root.add_child(panel)
	panel.open_file(FOLDER.path_join("main.tale"))
	panel.show_view("map")
	await tree.process_frame
	assert_true(panel.story_map.visible)
	assert_eq(panel.story_map.graph.beats.size(), 5, "the whole folder is shown")
	panel.story_map.link("main.forgotten", "main.start")
	assert_eq(panel.get_current_path(), FOLDER.path_join("main.tale"))
	assert_true(panel.code_edit.text.ends_with("beat forgotten:\n\tjump start\n"), panel.code_edit.text)
	assert_eq(panel.story_map.graph.unreachable, PackedStringArray(["main.forgotten"]), "the map was redrawn")
	panel.story_map.open_beat("side.right")
	assert_eq(panel.get_current_path(), FOLDER.path_join("side.tale"))
	assert_eq(panel.view, "cards")
	assert_eq(panel.card_editor.current_beat, "right")
	assert_true(panel.is_dirty(FOLDER.path_join("main.tale")), "the edit to main.tale is kept unsaved")

extends "res://tests/framework/story_test.gd"
## Tests for the Studio's map of scenes (studio/map/scene_map.gd): every
## scene as a box with arrows, the start and the endings marked, problems
## shown in plain words, and tapping a scene to open it.

const ROOT := "user://test_map_stories"
const TALE := """beat start:
	"Two paths."
	choose:
		"Go left":
			jump left_path
		"Go right":
			jump right_path

beat left_path:
	"Trees."
	jump finale

beat right_path:
	"A river."
	jump lost_scene

beat finale:
	"The end."

beat forgotten:
	"Nobody comes here."
"""


func _map(text := TALE, current := "start") -> StudioSceneMap:
	var map: StudioSceneMap = track(StudioSceneMap.new())
	tree.root.add_child(map)
	map.show_story(TaleParser.parse(text), "trip", current)
	return map


func test_every_scene_has_a_box() -> void:
	var map := _map()
	var scenes := Array(map.get_scenes())
	scenes.sort()
	assert_eq(scenes, ["finale", "forgotten", "left_path", "right_path", "start"])
	assert_eq(map.box_rows("left_path")[0], "Left path", "scenes show their names as students see them")


func test_boxes_show_the_start_choices_endings_and_problems() -> void:
	var map := _map()
	assert_eq(Array(map.box_rows("start")), ["Start", "▶ The story starts here", "“Go left” → Left path", "“Go right” → Right path"])
	assert_has(map.box_rows("finale"), "■ The story can end here")
	assert_has(map.box_rows("forgotten"), "⚠ No way to get here yet")
	assert_has(map.box_rows("right_path"), "⚠ Goes to a scene that isn't there: Lost scene")
	assert_false(map.box_rows("left_path").has("⚠ No way to get here yet"))


func test_scenes_go_left_to_right_in_the_order_they_play() -> void:
	var map := _map()
	assert_true(map.get_box("start").position.x < map.get_box("left_path").position.x)
	assert_true(map.get_box("left_path").position.x < map.get_box("finale").position.x)
	assert_eq(map.get_box("left_path").position.x, map.get_box("right_path").position.x, "both options are one step on")
	var left: Button = map.get_box("left_path")
	assert_true(left.get_rect().intersection(map.get_box("right_path").get_rect()).get_area() == 0.0, "boxes don't overlap")


func test_tapping_a_scene_chooses_it_and_closes_the_map() -> void:
	var map := _map()
	var chosen := []
	map.scene_chosen.connect(func(beat_name: String) -> void: chosen.append(beat_name))
	map.get_box("finale").pressed.emit()
	assert_eq(chosen, ["finale"])
	assert_true(map.is_queued_for_deletion())


func test_the_map_opens_from_the_blocks() -> void:
	StudioLibrary._remove_folder(ROOT)
	var studio: Control = track(preload("res://studio/studio.tscn").instantiate())
	studio.library_root = ROOT
	studio.settings_path = "user://test_map_settings.json"
	tree.root.add_child(studio)
	await tree.process_frame
	var id: String = studio.library.create("Trip", TALE)
	studio.open_story(id)
	var editor: StudioBlockEditor = studio.story.editor
	var map_button: Button = editor.scene_tabs.get_children().filter(func(child: Node) -> bool: return child.has_meta("map_button"))[0]
	map_button.pressed.emit()
	var map: StudioSceneMap = studio.story.find_children("*", "StudioSceneMap", true, false)[0]
	assert_eq(map.current_scene, "start")
	map.get_box("right_path").pressed.emit()
	assert_eq(editor.current_scene, "right_path", "the chosen scene opens in the blocks")
	await tree.process_frame
	assert_true(studio.story.find_children("*", "StudioSceneMap", true, false).is_empty())
	StudioLibrary._remove_folder(ROOT)
	if FileAccess.file_exists("user://test_map_settings.json"):
		DirAccess.remove_absolute("user://test_map_settings.json")
	var story: Node = tree.root.get_node("Story")
	story.start(story.load_config())

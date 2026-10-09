extends "res://tests/framework/story_test.gd"
## Tests for the route chart: RouteLog, what the director records in it,
## the RouteChart layout, its view, and the Routes tab in Extras.

const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")
const StoryScript := preload("res://addons/storyteller/core/story.gd")
const SAVE_FOLDER := "user://test_route_chart_saves"
const SETTINGS_PATH := "user://test_route_chart_settings.cfg"
const MAIN := "@title(\"Main\")\nvar friend := \"Mira\"\n\n@heading(\"Waking up\")\nbeat start:\n\t\"Morning.\"\n\tchoose:\n\t\t\"Get up\": jump up\n\t\t\"Sleep in\": jump sleep\n\t\t\"Secret door\" if false: pass\n\n@heading(\"Up early\")\nbeat up:\n\tchoose:\n\t\t\"Wave at {friend}[pause]\": pass\n\tjump other.start\n\nbeat sleep:\n\t\"Zzz.\"\n"
const OTHER := "beat start:\n\t\"Elsewhere.\"\n"

var director: TaleDirector
var presenter: ScriptedPresenter


func before_each() -> void:
	_clean()
	director = track(TaleDirector.new())
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(director)
	tree.root.add_child(presenter)
	director.presenter = presenter
	_add(director, "other", OTHER)
	_add(director, "main", MAIN)


func after_each() -> void:
	_clean()


func _clean() -> void:
	if DirAccess.dir_exists_absolute(SAVE_FOLDER):
		for file_name in DirAccess.get_files_at(SAVE_FOLDER):
			DirAccess.remove_absolute(SAVE_FOLDER.path_join(file_name))
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _add(target: TaleDirector, tale_name: String, source: String) -> void:
	var result := TaleCompiler.build(source, tale_name, target.make_check_context(tale_name))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail("%s: %s" % [tale_name, diagnostic])
	target.add_tale(result["tale"])


func _play(picks: Array) -> void:
	director.clear()
	presenter.picks = picks
	await director.play("main")


## Translation key of the option of main whose text is [param text].
func _option_key(text: String) -> String:
	var tale := director.get_tale("main")
	for id in tale.texts:
		if tale.texts[id] == text:
			return tale.translation_key(id)
	fail("no option '%s'" % text)
	return ""


func test_route_log_records_beats_links_and_options() -> void:
	var routes := RouteLog.new()
	assert_true(routes.is_empty())
	routes.enter("a.start")
	routes.enter("a.next", "a.start")
	routes.enter("a.next", "a.next")
	routes.enter("a.start", "a.next")
	routes.see_option("a:1")
	routes.see_option("a:2")
	routes.pick_option("a:2")
	routes.see_option("a:2")
	assert_eq(routes.beats, PackedStringArray(["a.start", "a.next"]))
	assert_eq(routes.get_links(), [["a.start", "a.next"], ["a.next", "a.start"]], "no link from a beat to itself")
	assert_eq([routes.get_option_state("a:1"), routes.get_option_state("a:2"), routes.get_option_state("a:3")], [RouteLog.SEEN, RouteLog.PICKED, RouteLog.UNSEEN])
	var copy := RouteLog.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(routes.to_dict())))
	assert_eq(copy.to_dict(), routes.to_dict(), "survives a trip through JSON")


func test_director_records_routes_across_playthroughs() -> void:
	await _play(["Get up"])
	var routes := director.routes
	assert_eq(routes.beats, PackedStringArray(["main.start", "main.up", "other.start"]))
	assert_eq(routes.get_links(), [["main.start", "main.up"], ["main.up", "other.start"]])
	assert_eq(routes.get_option_state(_option_key("Get up")), RouteLog.PICKED)
	assert_eq(routes.get_option_state(_option_key("Sleep in")), RouteLog.SEEN)
	assert_eq(routes.get_option_state(_option_key("Secret door")), RouteLog.UNSEEN, "a hidden option was never shown")
	await _play(["Sleep in"])
	assert_eq(routes.beats, PackedStringArray(["main.start", "main.up", "other.start", "main.sleep"]), "a new game keeps what was explored")
	assert_eq(routes.get_option_state(_option_key("Sleep in")), RouteLog.PICKED)


func test_routes_are_saved_with_the_global_data() -> void:
	await _play(["Get up"])
	var second: TaleDirector = track(TaleDirector.new())
	second.restore_globals(JSON.parse_string(JSON.stringify(director.capture_globals())))
	assert_eq(second.routes.to_dict(), director.routes.to_dict())
	var older := director.capture_globals()
	older.erase("routes")
	second.restore_globals(JSON.parse_string(JSON.stringify(older)))
	assert_true(second.routes.is_empty(), "older global files have no routes")


func test_chart_layout() -> void:
	await _play(["Get up"])
	var chart := RouteChart.build(director.routes, director)
	assert_eq(chart.bands.map(func(band: Dictionary) -> String: return band["title"]), ["Main", "Other"])
	assert_eq(chart.nodes.map(func(node: Dictionary) -> String: return node["title"]), ["Waking up", "Up early", "Start"], "headings, or the beat name")
	var start: Dictionary = chart.nodes[chart.find_node("main.start")]
	assert_eq(start["choices"], [[{"text": "Get up", "picked": true}, {"text": "Sleep in", "picked": false}]], "options never shown are left out")
	var up: Dictionary = chart.nodes[chart.find_node("main.up")]
	assert_eq(up["choices"], [[{"text": "Wave at …", "picked": true}]], "values and markup are not shown")
	assert_eq(chart.links, [{"from": 0, "to": 1}, {"from": 1, "to": 2}])
	assert_eq(start["position"], Vector2(0, RouteChart.BAND_TITLE_HEIGHT))
	assert_eq(up["position"].x, RouteChart.NODE_WIDTH + RouteChart.COLUMN_GAP, "one column to the right")
	var elsewhere: Dictionary = chart.nodes[2]
	assert_eq(elsewhere["position"].x, 0.0, "a tale's entry starts its band")
	assert_true(elsewhere["position"].y > start["position"].y + start["size"].y, "the second band is below the first")
	assert_eq(chart.size.x, RouteChart.NODE_WIDTH * 2 + RouteChart.COLUMN_GAP)
	assert_eq(chart.size.y, elsewhere["position"].y + elsewhere["size"].y)


func test_branches_share_a_column() -> void:
	await _play(["Get up"])
	await _play(["Sleep in"])
	var chart := RouteChart.build(director.routes, director)
	var up: Dictionary = chart.nodes[chart.find_node("main.up")]
	var sleep: Dictionary = chart.nodes[chart.find_node("main.sleep")]
	assert_eq(sleep["position"].x, up["position"].x)
	assert_eq(sleep["position"].y, up["position"].y + up["size"].y + RouteChart.ROW_GAP)


func test_beats_of_removed_tales_are_skipped() -> void:
	director.routes.enter("gone.start")
	director.routes.enter("main.missing", "gone.start")
	director.routes.enter("main.start", "main.missing")
	var chart := RouteChart.build(director.routes, director)
	assert_eq(chart.nodes.map(func(node: Dictionary) -> String: return node["id"]), ["main.start"])
	assert_eq(chart.links, [])


func test_view_shows_a_panel_per_beat() -> void:
	await _play(["Get up"])
	var view: RouteChartView = track(RouteChartView.new())
	tree.root.add_child(view)
	view.show_chart(RouteChart.build(director.routes, director))
	await tree.process_frame
	assert_eq(view.panels.size(), 3)
	var texts := view.panels[0].find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	assert_eq(texts, ["Waking up", "Get up", "Sleep in"])
	assert_true(view.custom_minimum_size.x > view.chart.size.x)
	for i in view.panels.size():
		assert_eq(view.panels[i].size, view.chart.nodes[i]["size"], "panel %d keeps the size the layout gave it" % i)


func test_extras_shows_routes_once_the_player_has_played() -> void:
	var story: Node = await _make_story(true)
	var menus: StoryMenus = story.get_crew(&"Menus")
	var story_director: TaleDirector = story.get_crew(&"TaleDirector")
	_add(story_director, "other", OTHER)
	_add(story_director, "main", MAIN)
	menus.show_title()
	await tree.process_frame
	assert_null(_button(story, "Extras"), "nothing to show yet")
	story_director.routes.enter("main.start")
	menus.show_title()
	await tree.process_frame
	_button(story, "Extras").pressed.emit()
	await tree.process_frame
	var screen: ExtrasScreen = story.find_child("ExtrasScreen", true, false)
	var tabs: TabContainer = screen.find_children("*", "TabContainer", true, false)[0]
	assert_eq(tabs.get_tab_count(), 1)
	assert_eq(tabs.get_tab_title(0), "Routes")
	var view: RouteChartView = tabs.find_child("RouteChartView", true, false)
	assert_eq(view.panels.size(), 1)


func test_route_chart_can_be_turned_off() -> void:
	var story: Node = await _make_story(false)
	var story_director: TaleDirector = story.get_crew(&"TaleDirector")
	story_director.routes.enter("main.start")
	story.get_crew(&"Menus").show_title()
	await tree.process_frame
	assert_null(_button(story, "Extras"))


func _make_story(show_route_chart: bool) -> Node:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StorySaves, StorySettings, StoryDialogue, StoryMenus]
	config.save_folder = SAVE_FOLDER
	config.settings_path = SETTINGS_PATH
	config.show_route_chart = show_route_chart
	var made: Node = track(StoryScript.new())
	made.start(config)
	tree.root.add_child(made)
	await tree.process_frame
	return made


func _button(story: Node, text: String) -> Button:
	for button in story.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree():
			return button
	return null

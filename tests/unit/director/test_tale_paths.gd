extends "res://tests/framework/story_test.gd"
## Tests for TalePaths (addons/storyteller/director/tale_paths.gd): a story
## played down every path finds its endings, errors, loops, and scenes no
## path reaches.

const TALE := """var brave := false
var name := ""

beat start:
	name = await ask_text("Your name?", "Robin")
	"Hello, {name}."
	choose:
		"Fight":
			brave = true
			jump fight
		"Run":
			jump run

beat fight:
	game.reward(2)
	if game.score > 1:
		"You won a prize."
	choose:
		"Shout" if brave:
			"A mighty shout."
		"Stay quiet":
			"Silence."
	jump ending

beat run:
	choose(timeout = 2.0):
		"Hide":
			music("no_such_track")
			jump ending
		timeout:
			"Too slow."
			jump ending

beat ending:
	"The end, {name}."

beat forgotten:
	"Nobody comes here."
"""

const LOOP := """beat start:
	choose:
		"Again":
			jump start
		"Leave":
			"Bye."
"""

var paths: TalePaths


func before_each() -> void:
	super()
	paths = track(TalePaths.new())
	tree.root.add_child(paths)


func _config() -> StoryConfig:
	var config := StoryConfig.new()
	config.tales_folder = "user://test_paths_tales"
	config.exposed_names = PackedStringArray(["game"])
	return config


func test_every_path_is_played_with_its_ending() -> void:
	var report := await paths.explore(_config(), "trip", "start", {"trip": TALE})
	# Fight: Shout or Stay quiet. Run: Hide, or the time runs out.
	assert_eq(report["paths"], 4)
	assert_true(report["complete"])
	assert_eq(report["endings"], {"trip.ending": 4})
	assert_eq(report["unreached"], PackedStringArray(["forgotten"]))


func test_problems_name_the_path_that_meets_them() -> void:
	var report := await paths.explore(_config(), "trip", "start", {"trip": TALE})
	assert_eq(report["problems"].size(), 1)
	var problem: Dictionary = report["problems"][0]
	assert_eq(problem["kind"], "error")
	assert_true(problem["message"].contains("no_such_track"), problem["message"])
	assert_eq(Array(problem["path"]), ["Run", "Hide"])
	var words := TalePaths.describe(report)
	assert_true(words.contains("4 paths played."), words)
	assert_true(words.contains("Never reached: forgotten"), words)
	assert_true(words.contains("after: Run > Hide"), words)


func test_a_loop_is_reported_and_the_rest_still_played() -> void:
	paths.max_choices = 4
	var report := await paths.explore(_config(), "loop", "start", {"loop": LOOP})
	assert_eq(report["endings"].get("loop.start", 0), report["paths"] - 1, "every path but the endless one ends")
	var loops: Array = report["problems"].filter(func(problem: Dictionary) -> bool: return problem["kind"] == "loop")
	assert_eq(loops.size(), 1)
	assert_eq(Array(loops[0]["path"]), ["Again", "Again", "Again", "Again"])


func test_a_tale_with_mistakes_is_not_played() -> void:
	var report := await paths.explore(_config(), "broken", "start", {"broken": "beat start:\n\tjump nowhere\n"})
	assert_eq(report["paths"], 0)
	assert_eq(report["problems"][0]["message"], "Unknown beat 'nowhere'.")


func test_next_plan_tries_each_option_once() -> void:
	var trace := [{"options": [0, 1], "pick": 0}, {"options": [0, 1, 2], "pick": 2}]
	assert_eq(TalePaths.next_plan(trace), [1])
	trace = [{"options": [0, 1], "pick": 0}, {"options": [0, 1, 2], "pick": 1}]
	assert_eq(TalePaths.next_plan(trace), [0, 2])
	assert_eq(TalePaths.next_plan([{"options": [0, -1], "pick": -1}]), [])

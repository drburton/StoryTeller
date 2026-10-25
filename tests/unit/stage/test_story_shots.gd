extends "res://tests/framework/story_test.gd"
## Tests for StoryShots (addons/storyteller/stage/story_shots.gd): tales play
## a scene's animations as shots, wait for them, hold looping poses, and get
## the scene back after loading or rewinding.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const ScriptedPresenter := preload("res://tests/fixtures/scripted_presenter.gd")

var story: Node
var director: TaleDirector
var shots: StoryShots
var presenter: ScriptedPresenter
var player: AnimationPlayer
var errors: Array[String] = []


func before_each() -> void:
	var config := StoryConfig.new()
	config.crew = [TaleDirector, StoryShots]
	story = track(StoryScript.new())
	story.start(config)
	tree.root.add_child(story)
	director = story.get_crew(&"TaleDirector")
	shots = story.get_crew(&"Shots")
	presenter = track(ScriptedPresenter.new())
	tree.root.add_child(presenter)
	director.presenter = presenter
	errors.clear()
	director.runtime_error.connect(func(message: String, _tale: String, line: int) -> void:
		errors.append("%d: %s" % [line, message]))
	player = track(_player())
	tree.root.add_child(player)
	shots.use(player)
	await tree.process_frame


# An AnimationPlayer with two short shots and a looping pose, each moving
# its own track so the frame showing can be told apart.
static func _player() -> AnimationPlayer:
	var animation_player := AnimationPlayer.new()
	var marker := Node.new()
	marker.name = "Marker"
	marker.set_meta("x", 0.0)
	animation_player.add_child(marker)
	var library := AnimationLibrary.new()
	for spec in [["approach", 0.2, false, 1.0], ["jump", 0.15, false, 2.0], ["idle", 0.3, true, 3.0]]:
		var animation := Animation.new()
		animation.length = spec[1]
		animation.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("Marker:editor_description"))
		animation.track_insert_key(track, 0.0, "%s start" % spec[0])
		animation.track_insert_key(track, spec[1], "%s end" % spec[0])
		animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		library.add_animation(spec[0], animation)
	animation_player.add_animation_library("", library)
	animation_player.root_node = NodePath(".")
	return animation_player


func _play(source: String) -> void:
	var result := TaleCompiler.build(source, "main", director.make_check_context("main"))
	for diagnostic in result["diagnostics"]:
		if diagnostic.is_error():
			fail(str(diagnostic))
	if result["tale"]:
		director.add_tale(result["tale"])
		await director.play("main")


func _marker() -> String:
	return player.get_node("Marker").editor_description


func test_a_tale_waits_for_each_shot_and_holds_a_pose() -> void:
	var started := []
	shots.shot_started.connect(func(shot: String, holding: bool) -> void: started.append([shot, holding]))
	presenter.picks = ["Jump the gap"]
	var at_line := []
	presenter.on_line = func(_line: Dictionary) -> void: at_line.append([_marker(), str(player.current_animation)])
	await _play("beat start:\n\tawait shots.play(\"approach\")\n\tshots.hold(\"idle\")\n\t\"Which way?\"\n\tchoose:\n\t\t\"Jump the gap\":\n\t\t\tawait shots.play(\"jump\")\n\t\t\"Stay\":\n\t\t\t\"You wait.\"\n")
	assert_eq(errors, [])
	assert_eq(started, [["approach", false], ["idle", true], ["jump", false]])
	assert_eq(at_line, [["approach end", "idle"]], "the line waits for the shot, and the pose holds while it shows")
	assert_eq(_marker(), "jump end", "the tale waited for the last shot")
	assert_eq(presenter.lines, ["Which way?"])
	assert_eq(shots.current, "jump")
	assert_false(shots.holding)


func test_a_looping_shot_does_not_hold_up_the_tale() -> void:
	await _play("beat start:\n\tawait shots.play(\"idle\")\n\t\"Still going.\"\n")
	assert_eq(errors, [])
	assert_eq(presenter.lines, ["Still going."])
	assert_eq(player.current_animation, "idle")


func test_loading_or_rewinding_puts_the_scene_back() -> void:
	await shots.play("approach")
	var saved := shots.capture()
	assert_eq(saved, {"current": "approach", "holding": false})
	shots.hold("idle")
	shots.restore(saved)
	assert_eq(_marker(), "approach end", "a played shot shows its last frame")
	shots.restore({"current": "idle", "holding": true})
	assert_eq(player.current_animation, "idle")
	assert_true(player.is_playing(), "a held pose plays again")


func test_a_scene_given_after_loading_gets_the_saved_shot() -> void:
	var later: AnimationPlayer = track(_player())
	tree.root.add_child(later)
	shots.restore({"current": "jump", "holding": false})
	shots.use(later)
	assert_eq(later.get_node("Marker").editor_description, "jump end")


func test_skipping_jumps_to_the_end_of_a_shot() -> void:
	director.skipping = true
	var frames := [0]
	var count := func() -> void: frames[0] += 1
	tree.process_frame.connect(count)
	await shots.play("approach")
	tree.process_frame.disconnect(count)
	assert_eq(frames[0], 0, "no waiting while skipping")
	assert_eq(_marker(), "approach end")


func test_without_a_scene_shots_do_nothing() -> void:
	shots.teardown()
	await shots.play("approach")
	assert_eq(shots.current, "approach")
	assert_false(shots.has_shot("approach"))
	shots.clear()
	assert_eq(shots.capture(), {"current": "", "holding": false})

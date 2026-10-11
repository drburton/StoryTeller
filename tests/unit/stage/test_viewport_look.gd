extends "res://tests/framework/story_test.gd"
## Tests for ViewportLook: a 3D scene shown on the stage through a viewport.


## A small 3D character: a box, and an AnimationPlayer with "smile" and
## "wave" animations.
func _scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "Model"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	root.add_child(body)
	body.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	for animation_name in ["smile", "wave"]:
		var animation := Animation.new()
		animation.length = 0.2
		library.add_animation(animation_name, animation)
	player.add_animation_library("", library)
	root.add_child(player)
	player.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_the_scene_is_shown_through_a_viewport() -> void:
	var look := ViewportLook.new()
	look.scene = _scene()
	look.size = Vector2i(200, 300)
	var visual: Node2D = track(look.create_visual())
	tree.root.add_child(visual)
	var viewport: SubViewport = visual.get_node("Viewport")
	assert_eq(viewport.size, Vector2i(200, 300))
	assert_true(viewport.transparent_bg)
	assert_not_null(viewport.get_node_or_null("Model/Body"), "the scene is inside the viewport")
	assert_eq(viewport.find_children("*", "Camera3D", true, false).size(), 1, "a camera is added when the scene has none")
	var picture: Sprite2D = visual.get_node("Picture")
	assert_true(picture.texture is ViewportTexture)
	assert_eq(picture.offset, Vector2(0, -150), "the feet are at the origin")


func test_moods_play_the_scenes_animations() -> void:
	var look := ViewportLook.new()
	look.scene = _scene()
	var visual: Node2D = track(look.create_visual())
	tree.root.add_child(visual)
	assert_true(look.apply_mood(visual, "smile"))
	var player: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)
	assert_eq(player.current_animation, "smile")
	assert_false(look.apply_mood(visual, "furious"))


func test_a_viewport_character_on_stage() -> void:
	var stage: StoryStage = track(StoryStage.new())
	stage.setup(StoryConfig.new())
	tree.root.add_child(stage)
	var profile := CastProfile.new()
	profile.id = "cube"
	var look := ViewportLook.new()
	look.scene = _scene()
	profile.look = look
	stage.add_profile(profile)
	var cube := stage.get_cast("cube")
	cube.enter("smile", Vector2(0.5, 0.0), 0.0)
	assert_eq(cube.mood, "smile")
	var player: AnimationPlayer = cube.find_child("AnimationPlayer", true, false)
	cube.animate("wave")
	assert_eq(player.current_animation, "wave", "named animations play")
	await tree.create_timer(0.4).timeout
	assert_eq(player.current_animation, "smile", "and the mood comes back after")

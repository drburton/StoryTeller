@tool
class_name ViewportLook
extends CastLook
## Draws a cast member with a 3D scene, rendered into its own viewport and
## shown on the stage like a sprite. Moods work as in [SceneLook]: the
## scene's [code]set_mood(mood)[/code] method when it has one, or the
## [AnimationPlayer] animation with the mood's name, and
## [code]animate(name)[/code] plays any animation.
##
## The scene is lit and filmed by its own [Camera3D] and lights. Without a
## camera, one is placed in front of the origin looking at chest height;
## without a light, a key light is added, and without a [WorldEnvironment],
## soft ambient light so the shaded side is not black.

## 3D scene to show. Its root is usually a [Node3D] with the character
## standing at the origin, facing +Z.
@export var scene: PackedScene
## Size of the picture in pixels. Its bottom center is the character's feet
## on stage.
@export var size := Vector2i(512, 768)
## Show the stage behind the character instead of the 3D world's sky.
@export var transparent_background := true
## Moods to report to the checker. Leave empty to accept any name.
@export var mood_names: PackedStringArray = []


func create_visual() -> Node2D:
	var root := Node2D.new()
	root.name = "Viewport3D"
	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = size
	viewport.own_world_3d = true
	viewport.transparent_bg = transparent_background
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	if scene != null:
		viewport.add_child(scene.instantiate())
	if viewport.find_children("*", "Camera3D", true, false).is_empty():
		var camera := Camera3D.new()
		camera.name = "Camera"
		camera.position = Vector3(0, 1.2, 3.2)
		camera.fov = 40.0
		viewport.add_child(camera)
		camera.look_at_from_position(camera.position, Vector3(0, 1.0, 0))
	if viewport.find_children("*", "Light3D", true, false).is_empty():
		var light := DirectionalLight3D.new()
		light.name = "Light"
		light.rotation_degrees = Vector3(-35, 30, 0)
		viewport.add_child(light)
	if viewport.find_children("*", "WorldEnvironment", true, false).is_empty():
		var environment := Environment.new()
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.75, 0.75, 0.8)
		environment.ambient_light_energy = 0.6
		var world := WorldEnvironment.new()
		world.name = "Environment"
		world.environment = environment
		viewport.add_child(world)
	var picture := Sprite2D.new()
	picture.name = "Picture"
	picture.texture = viewport.get_texture()
	picture.offset = Vector2(0, -size.y / 2.0)
	# A transparent viewport gives premultiplied colors; drawing them that
	# way avoids a dark fringe around the character.
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	picture.material = blend
	root.add_child(picture)
	return root


func apply_mood(visual: Node2D, mood: String) -> bool:
	var model := _model(visual)
	if model != null and model.has_method("set_mood"):
		var result: Variant = model.call("set_mood", mood)
		return result != false
	var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation(mood):
		player.play(mood)
		return true
	return false


func get_moods() -> PackedStringArray:
	return mood_names


## The instanced scene inside [param visual], or null.
func _model(visual: Node2D) -> Node:
	var viewport := visual.get_node_or_null("Viewport")
	if viewport == null or viewport.get_child_count() == 0:
		return null
	return viewport.get_child(0)

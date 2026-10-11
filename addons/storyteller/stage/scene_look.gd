@tool
class_name SceneLook
extends CastLook
## Draws a cast member with any scene. Moods call the scene's
## [code]set_mood(mood)[/code] method when it has one, or play the
## [AnimationPlayer] animation with the mood's name.

## Scene to instantiate. Its root must be a Node2D whose origin is the
## character's bottom center.
@export var scene: PackedScene
## Moods to report to the checker. Leave empty to accept any name.
@export var mood_names: PackedStringArray = []


func create_visual() -> Node2D:
	if scene == null:
		return Node2D.new()
	return scene.instantiate() as Node2D


func apply_mood(visual: Node2D, mood: String) -> bool:
	if visual.has_method("set_mood"):
		var result: Variant = visual.call("set_mood", mood)
		return result != false
	var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation(mood):
		player.play(mood)
		return true
	return false


func get_moods() -> PackedStringArray:
	return mood_names

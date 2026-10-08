class_name TaleContext
extends RefCounted
## Passed to every action. Gives access to the director and the crew, and
## helpers that respect skipping.

var director: TaleDirector


func _init(p_director: TaleDirector) -> void:
	director = p_director


## True while the player is skipping. Actions should finish instantly.
func is_skipping() -> bool:
	return director.skipping


## Waits [param seconds], or returns at once while skipping.
func wait(seconds: float) -> void:
	if seconds <= 0.0 or director.skipping or not director.is_inside_tree():
		return
	await director.get_tree().create_timer(seconds).timeout


## Returns another crew member, e.g. [code]ctx.get_crew(&"Audio")[/code].
func get_crew(crew_name: StringName) -> StoryCrew:
	var story := director.get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(crew_name)
	return null

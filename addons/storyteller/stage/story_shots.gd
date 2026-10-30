class_name StoryShots
extends StoryCrew
## Plays a scene's animations for tales, one shot at a time, and keeps the
## shot showing in saves and rewind. Made for stories told in your own 3D
## (or 2D) scene, such as characters rigged and animated in Blender and
## imported as .glb, which pause for the player's choices.
##
## Add it to the crew, then give it the scene's AnimationPlayer:
## [codeblock]
## config.crew.append(StoryShots)      # or the Crew list in the inspector
## Story.get_crew(&"Shots").use($AnimationPlayer)
## [/codeblock]
## Tales use it as [code]shots[/code] (list it in StoryConfig.exposed_names
## so the checker knows it):
## [codeblock]
## await shots.play("approach")   # plays a shot and waits for its end
## shots.hold("idle_wait")        # starts a looping pose; the tale goes on
## choose:
##     "Jump the gap":
##         await shots.play("jump_gap")
## [/codeblock]
## Loading a save or rewinding puts the scene back: the shot last played
## shows its final frame, or the held pose plays again. While the player
## skips, a shot jumps to its last frame.

## Emitted when a shot starts. [param holding] is true for a held pose.
signal shot_started(shot: String, holding: bool)

## The AnimationPlayer the shots come from. Set it with [method use].
var player: AnimationPlayer
## The shot showing, or "".
var current := ""
## True when [member current] is a held pose rather than a played shot.
var holding := false


func get_crew_name() -> StringName:
	return &"Shots"


## Plays shots from [param animation_player] from now on, and puts it in the
## state a loaded save or rewind asked for.
func use(animation_player: AnimationPlayer) -> void:
	player = animation_player
	_show_current()


## Plays [param shot] and returns when it ends. A looping animation returns
## at once. Does nothing until [method use] has given an AnimationPlayer.
func play(shot: String) -> void:
	current = shot
	holding = false
	shot_started.emit(shot, false)
	if not _has(shot):
		return
	player.play(shot)
	if _is_skipping():
		player.seek(player.current_animation_length, true)
		return
	if player.get_animation(shot).loop_mode != Animation.LOOP_NONE:
		return
	await player.animation_finished


## Starts [param shot], usually a looping pose, and returns at once.
func hold(shot: String) -> void:
	current = shot
	holding = true
	shot_started.emit(shot, true)
	if _has(shot):
		player.play(shot)


## True when the AnimationPlayer has an animation called [param shot].
func has_shot(shot: String) -> bool:
	return _has(shot)


func clear() -> void:
	current = ""
	holding = false
	if player != null and is_instance_valid(player):
		player.stop()


func capture() -> Dictionary:
	return {"current": current, "holding": holding}


func restore(data: Dictionary) -> void:
	current = str(data.get("current", ""))
	holding = bool(data.get("holding", false))
	_show_current()


func teardown() -> void:
	player = null


## Names tales may use.
func get_tale_names() -> PackedStringArray:
	return PackedStringArray(["shots"])


func resolve_tale_name(tale_name: String) -> Array:
	return [true, self] if tale_name == "shots" else [false, null]


func get_tale_api() -> Dictionary:
	return {"methods": PackedStringArray(["play", "hold", "has_shot"]), "properties": PackedStringArray(["current"])}


# Puts the scene where the story is: a held pose plays, and a played shot
# shows its last frame.
func _show_current() -> void:
	if current.is_empty() or not _has(current):
		return
	player.play(current)
	if not holding:
		player.seek(player.current_animation_length, true)


func _has(shot: String) -> bool:
	return player != null and is_instance_valid(player) and player.has_animation(shot)


func _is_skipping() -> bool:
	var story := get_parent()
	var director: TaleDirector = story.get_crew(&"TaleDirector") if story != null and story.has_method("get_crew") else null
	return director != null and director.skipping

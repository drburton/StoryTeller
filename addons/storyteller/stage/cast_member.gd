class_name CastMember
extends Node2D
## A character on stage, controlled from tales:
## [codeblock]
## mira.enter("smile", at = LEFT)
## mira.mood = "worried"
## mira.display_name = "???"
## await mira.move_to(CENTER, time = 0.6)
## mira.hop()
## mira.to_front()
## mira.exit()
## [/codeblock]
## Positions are fractions of the screen: x from 0 (left edge) to 1 (right
## edge), y lifts the character's feet above the bottom of the screen.

signal mood_changed(mood: String)

## Tint applied to speakers who are not talking, when highlighting is on.
const DIMMED := Color(0.6, 0.6, 0.65)

var profile: CastProfile
## Where the character stands, as a stage position (see class description).
var stage_position := Vector2(0.5, 0.0)
## Current mood. Setting it changes the look immediately.
var mood := "":
	set = set_mood
## Color multiplied over the character.
var tint := Color.WHITE:
	set(value):
		tint = value
		_update_modulate()
## Mirrors the character horizontally.
var flip := false:
	set(value):
		flip = value
		if _visual:
			_visual.scale.x = -absf(_visual.scale.x) if flip else absf(_visual.scale.x)
## Name shown in the dialogue box: the profile's name until a tale sets
## another, such as "???" before the character introduces themselves, or a
## name the player typed. Setting "" goes back to the profile's name. The
## name is saved, and translated by its text like the profile's name.
var display_name: Variant:
	get:
		return _display_name if not _display_name.is_empty() else profile.get_display_name()
	set(value):
		_display_name = str(value) if value != null else ""
## Drawing order among cast members: higher numbers draw in front. Members
## with the same number draw in the order they were first used.
var draw_order := 0:
	set(value):
		draw_order = value
		z_index = clampi(value, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)
## True between enter() and exit().
var on_stage := false
## Returns true while the player skips; animations then finish at once.
var is_skipping := func() -> bool: return false
## Called with a message when a tale asks for something this member can't
## do, such as an animation its look doesn't have. The Stage reports it
## through the director.
var report_error := func(message: String) -> void: push_warning("StoryTeller: " + message)

var _visual: Node2D
## Name set during play, or "" for the profile's name.
var _display_name := ""
## Values of the profile's fields ([member CastProfile.fields]).
var _fields: Dictionary = {}
var _alpha := 1.0
## Offset of the look from hop(), shake(), and nod().
var _motion := Vector2.ZERO
var _highlight := Color.WHITE
var _tweens: Array[Tween] = []


func setup(p_profile: CastProfile) -> void:
	profile = p_profile
	name = profile.id
	if profile.look != null:
		_visual = profile.look.create_visual()
	else:
		_visual = Node2D.new()
	_visual.scale = Vector2.ONE * profile.scale
	add_child(_visual)
	visible = false
	if not profile.default_mood.is_empty():
		set_mood(profile.default_mood)
	for problem in profile.get_field_problems():
		push_warning("StoryTeller: " + problem)
	reset_fields()


## What tales may use on this object.
func get_tale_api() -> Dictionary:
	return {
		"methods": PackedStringArray(["enter", "exit", "move_to", "scale_to", "hop", "shake", "nod", "animate", "to_front", "to_back"]),
		"properties": PackedStringArray(["mood", "tint", "flip", "on_stage", "display_name", "draw_order"]) + PackedStringArray(_fields.keys()),
	}


## The value of the field [param field] (see [member CastProfile.fields]),
## or null when the profile has no such field.
func get_field(field: String) -> Variant:
	return _fields.get(field)


## Changes a field. Returns false when the profile has no such field.
func set_field(field: String, value: Variant) -> bool:
	if not _fields.has(field):
		return false
	_fields[field] = value
	return true


func has_field(field: String) -> bool:
	return _fields.has(field)


## Sets every field back to the profile's starting value.
func reset_fields() -> void:
	_fields.clear()
	if profile == null:
		return
	for field in profile.get_field_names():
		var value: Variant = profile.fields[field]
		_fields[field] = value.duplicate(true) if value is Array or value is Dictionary else value


# Fields read and written like properties, as tales do with ada.affection.
func _get(property: StringName) -> Variant:
	if _fields.has(property):
		return _fields[property]
	return null


func _set(property: StringName, value: Variant) -> bool:
	if _fields.has(property):
		_fields[property] = value
		return true
	return false


func get_display_name() -> String:
	return display_name


func get_name_color() -> Color:
	return profile.name_color


## Shows the character. [param transition] is "fade", "slide_left" (enters
## from the left edge), "slide_right", or "none".
func enter(mood_name := "", at := Vector2(0.5, 0.0), time := 0.4, transition := "fade") -> void:
	if not mood_name.is_empty():
		set_mood(mood_name)
	stage_position = at
	on_stage = true
	visible = true
	var target := stage_to_pixels(at)
	match transition:
		"slide_left", "slide_right":
			var width := _viewport_size().x
			position = Vector2(-width * 0.25 if transition == "slide_left" else width * 1.25, target.y)
			_set_alpha(1.0)
			await _animate("position", target, time)
		"none":
			position = target
			_set_alpha(1.0)
		_:
			position = target
			_set_alpha(0.0)
			await _animate_alpha(1.0, time)


## Hides the character. Transitions as in [method enter].
func exit(time := 0.4, transition := "fade") -> void:
	on_stage = false
	match transition:
		"slide_left", "slide_right":
			var width := _viewport_size().x
			await _animate("position", Vector2(-width * 0.25 if transition == "slide_left" else width * 1.25, position.y), time)
		"none":
			pass
		_:
			await _animate_alpha(0.0, time)
	if not on_stage:
		visible = false


## Moves the character to another stage position.
func move_to(at: Vector2, time := 0.5) -> void:
	stage_position = at
	await _animate("position", stage_to_pixels(at), time)


## Scales the character relative to its profile size.
func scale_to(factor: float, time := 0.3) -> void:
	await _animate("scale", Vector2.ONE * factor, time)


## Jumps up and lands. [param height] is a fraction of the screen height.
func hop(height := 0.04, time := 0.35) -> void:
	var lift := height * _viewport_size().y
	await _move_look(time, func(t: float) -> Vector2: return Vector2(0.0, -lift * sin(PI * t)))


## Shakes from side to side, fading out. At [param strength] 1 the
## character moves about 3% of the screen width each way.
func shake(strength := 0.5, time := 0.4) -> void:
	var reach := strength * 0.03 * _viewport_size().x
	await _move_look(time, func(t: float) -> Vector2: return Vector2(reach * sin(t * TAU * 4.0) * (1.0 - t), 0.0))


## Nods twice: dips a little and comes back up.
func nod(time := 0.5) -> void:
	var dip := 0.012 * _viewport_size().y
	await _move_look(time, func(t: float) -> Vector2: return Vector2(0.0, dip * absf(sin(t * TAU))))


## Plays the animation [param animation_name] of a scene-based look: the
## scene's [code]play_animation(name)[/code] method when it has one,
## otherwise the animation of that name in its [AnimationPlayer]. Awaitable:
## returns when the animation ends, or at once for a looping animation.
## Afterwards the character shows their mood again.
func animate(animation_name: String) -> void:
	if _visual != null and _visual.has_method("play_animation"):
		var result: Variant = await _visual.call("play_animation", animation_name)
		if result == false:
			report_error.call("%s has no animation '%s'." % [profile.id, animation_name])
		return
	var player := _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer if _visual != null else null
	if player == null or not player.has_animation(animation_name):
		report_error.call("%s has no animation '%s'. Named animations need a scene look with an AnimationPlayer." % [profile.id, animation_name])
		return
	var animation := player.get_animation(animation_name)
	player.play(animation_name)
	if animation.loop_mode != Animation.LOOP_NONE:
		return
	if is_skipping.call() or not is_inside_tree():
		player.seek(animation.length, true)
	else:
		await get_tree().create_timer(animation.length / maxf(absf(player.speed_scale), 0.01)).timeout
	if is_instance_valid(player) and player.current_animation in [animation_name, ""] and not mood.is_empty():
		set_mood(mood)


## Draws this character in front of the other cast members.
func to_front() -> void:
	var others := _other_orders()
	if not others.is_empty() and draw_order <= others.max():
		draw_order = others.max() + 1


## Draws this character behind the other cast members.
func to_back() -> void:
	var others := _other_orders()
	if not others.is_empty() and draw_order >= others.min():
		draw_order = others.min() - 1


func set_mood(value: String) -> void:
	if profile != null and profile.look != null and _visual != null and not value.is_empty():
		if not profile.look.apply_mood(_visual, value):
			push_warning("StoryTeller: %s has no mood '%s'." % [profile.id, value])
			return
	mood = value
	mood_changed.emit(value)


## Dims the character when someone else is speaking.
func set_highlighted(highlighted: bool) -> void:
	_highlight = Color.WHITE if highlighted else DIMMED
	_update_modulate()


## Converts a stage position to pixels in the current viewport.
func stage_to_pixels(at: Vector2) -> Vector2:
	var size := _viewport_size()
	return Vector2(at.x * size.x, size.y - at.y * size.y)


## Ends running animations at their final values.
func finish_animations() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.custom_step(1000.0)
			tween.kill()
	_tweens.clear()
	_set_motion(Vector2.ZERO)


## Places the character again after the window size changes.
func relayout() -> void:
	if on_stage:
		position = stage_to_pixels(stage_position)


func capture() -> Dictionary:
	return {
		"mood": mood,
		"at": [stage_position.x, stage_position.y],
		"on_stage": on_stage,
		"tint": [tint.r, tint.g, tint.b, tint.a],
		"flip": flip,
		"scale": scale.x,
		"display_name": _display_name,
		"draw_order": draw_order,
		"fields": JSON.from_native(_fields),
	}


func restore(data: Dictionary) -> void:
	finish_animations()
	if data.get("mood", "") != "":
		set_mood(data["mood"])
	var at: Array = data.get("at", [0.5, 0.0])
	stage_position = Vector2(at[0], at[1])
	on_stage = data.get("on_stage", false)
	var color: Array = data.get("tint", [1.0, 1.0, 1.0, 1.0])
	tint = Color(color[0], color[1], color[2], color[3])
	flip = data.get("flip", false)
	scale = Vector2.ONE * float(data.get("scale", 1.0))
	_display_name = str(data.get("display_name", ""))
	draw_order = int(data.get("draw_order", 0))
	reset_fields()
	# Fields saved before the profile dropped them are ignored; fields added
	# since keep their starting values.
	var saved_fields: Variant = JSON.to_native(data.get("fields", {}))
	if saved_fields is Dictionary:
		for field in saved_fields:
			if _fields.has(field):
				_fields[field] = saved_fields[field]
	visible = on_stage
	_set_alpha(1.0)
	relayout()


func _animate(property: String, value: Variant, time: float) -> void:
	if time <= 0.0 or is_skipping.call() or not is_inside_tree():
		set(property, value)
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, property, value, time)
	_tweens.append(tween)
	await tween.finished
	_tweens.erase(tween)


func _animate_alpha(value: float, time: float) -> void:
	if time <= 0.0 or is_skipping.call() or not is_inside_tree():
		_set_alpha(value)
		return
	var tween := create_tween()
	tween.tween_method(_set_alpha, _alpha, value, time)
	_tweens.append(tween)
	await tween.finished
	_tweens.erase(tween)


## Moves the look by [param offset_at] (from 0 to 1 over [param time]) and
## back to rest. Only the look moves, so it works during move_to().
func _move_look(time: float, offset_at: Callable) -> void:
	if time <= 0.0 or is_skipping.call() or not is_inside_tree():
		_set_motion(Vector2.ZERO)
		return
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _set_motion(offset_at.call(t)), 0.0, 1.0, time)
	_tweens.append(tween)
	await tween.finished
	_tweens.erase(tween)
	_set_motion(Vector2.ZERO)


func _set_motion(offset: Vector2) -> void:
	_motion = offset
	if _visual != null:
		_visual.position = offset


func _other_orders() -> Array:
	var orders := []
	if get_parent() != null:
		for sibling in get_parent().get_children():
			if sibling != self and sibling is CastMember:
				orders.append(sibling.draw_order)
	return orders


func _set_alpha(value: float) -> void:
	_alpha = value
	_update_modulate()


func _update_modulate() -> void:
	modulate = Color(tint.r * _highlight.r, tint.g * _highlight.g, tint.b * _highlight.b, tint.a * _alpha)


func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648))

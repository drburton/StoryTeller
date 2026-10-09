class_name CastMember
extends Node2D
## A character on stage, controlled from tales:
## [codeblock]
## mira.enter("smile", at = LEFT)
## mira.mood = "worried"
## mira.display_name = "???"
## await mira.move_to(CENTER, time = 0.6)
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
## True between enter() and exit().
var on_stage := false
## Returns true while the player skips; animations then finish at once.
var is_skipping := func() -> bool: return false

var _visual: Node2D
## Name set during play, or "" for the profile's name.
var _display_name := ""
var _alpha := 1.0
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


## What tales may use on this object.
func get_tale_api() -> Dictionary:
	return {
		"methods": PackedStringArray(["enter", "exit", "move_to", "scale_to"]),
		"properties": PackedStringArray(["mood", "tint", "flip", "on_stage", "display_name"]),
	}


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

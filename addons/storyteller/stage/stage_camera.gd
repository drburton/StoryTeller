class_name StageCamera
extends Node
## Moves the whole stage (backdrops, cast, props) like a camera. Tales use it
## as [code]camera[/code]:
## [codeblock]
## await camera.zoom(1.3, time = 0.8)
## camera.pan(Vector2(0.1, 0.0))
## camera.shake(0.5)
## camera.reset()
## [/codeblock]
## Pan offsets are fractions of the screen size.

## Layers the camera moves.
var layers: Array[CanvasLayer] = []
## Returns true while the player skips.
var is_skipping := func() -> bool: return false

var zoom_level := 1.0:
	set(value):
		zoom_level = value
		_apply()
var offset := Vector2.ZERO:
	set(value):
		offset = value
		_apply()
var angle := 0.0:
	set(value):
		angle = value
		_apply()

var _shake_strength := 0.0
var _shake_left := 0.0
var _shake_offset := Vector2.ZERO
var _tweens: Array[Tween] = []


func get_tale_api() -> Dictionary:
	return {
		"methods": PackedStringArray(["zoom", "pan", "rotate", "shake", "reset"]),
		"properties": PackedStringArray(["zoom_level", "offset", "angle"]),
	}


## Zooms toward the screen center. 1.0 is normal size.
func zoom(amount := 1.0, time := 0.5) -> void:
	await _animate("zoom_level", amount, time)


## Moves the view by a fraction of the screen, e.g. Vector2(0.1, 0).
func pan(to := Vector2.ZERO, time := 0.5) -> void:
	await _animate("offset", to, time)


## Tilts the view by [param degrees].
func rotate(degrees := 0.0, time := 0.5) -> void:
	await _animate("angle", deg_to_rad(degrees), time)


## Shakes the view. [param strength] 1.0 moves up to 3% of the screen width.
func shake(strength := 0.5, time := 0.4) -> void:
	if is_skipping.call() or time <= 0.0:
		return
	_shake_strength = strength
	_shake_left = time
	while _shake_left > 0.0 and is_inside_tree():
		await get_tree().process_frame
	_shake_offset = Vector2.ZERO
	_apply()


## Returns to normal zoom, position, and angle.
func reset(time := 0.5) -> void:
	zoom(1.0, time)
	pan(Vector2.ZERO, time)
	await rotate(0.0, time)


func finish_animations() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.custom_step(1000.0)
			tween.kill()
	_tweens.clear()
	_shake_left = 0.0
	_shake_offset = Vector2.ZERO
	_apply()


func capture() -> Dictionary:
	return {"zoom": zoom_level, "offset": [offset.x, offset.y], "angle": angle}


func restore(data: Dictionary) -> void:
	finish_animations()
	zoom_level = float(data.get("zoom", 1.0))
	var saved_offset: Array = data.get("offset", [0.0, 0.0])
	offset = Vector2(saved_offset[0], saved_offset[1])
	angle = float(data.get("angle", 0.0))


func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left -= delta
		var size := _screen_size()
		var amplitude := size.x * 0.03 * _shake_strength
		_shake_offset = Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude))
		_apply()


func _animate(property: String, value: Variant, time: float) -> void:
	if time <= 0.0 or is_skipping.call() or not is_inside_tree():
		set(property, value)
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, property, value, time)
	_tweens.append(tween)
	await tween.finished
	_tweens.erase(tween)


## Builds the layer transform: zoom and rotate around the screen center,
## then pan and shake.
func _apply() -> void:
	var size := _screen_size()
	var center := size / 2.0
	var view := Transform2D(angle, Vector2.ONE * zoom_level, 0.0, Vector2.ZERO)
	var shift := -offset * size * zoom_level + _shake_offset
	var transform := Transform2D.IDENTITY.translated(-center)
	transform = view * transform
	transform = transform.translated(center + shift)
	for layer in layers:
		layer.transform = transform


func _screen_size() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1152, 648)

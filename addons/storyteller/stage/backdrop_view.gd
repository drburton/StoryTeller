class_name BackdropView
extends Control
## Full-screen backdrop that blends between images or colors with a
## transition shader.

const TRANSITION_SHADER := preload("res://addons/storyteller/stage/transition.gdshader")
## Transition names and their shader settings: [mode, direction].
const TRANSITIONS := {
	"none": [0, Vector2.ZERO],
	"cut": [0, Vector2.ZERO],
	"fade": [1, Vector2.ZERO],
	"dissolve": [2, Vector2.ZERO],
	"wipe_left": [3, Vector2(-1, 0)],
	"wipe_right": [3, Vector2(1, 0)],
	"wipe_up": [3, Vector2(0, -1)],
	"wipe_down": [3, Vector2(0, 1)],
	"slide_left": [4, Vector2(-1, 0)],
	"slide_right": [4, Vector2(1, 0)],
	"slide_up": [4, Vector2(0, -1)],
	"slide_down": [4, Vector2(0, 1)],
}

## Emitted when a transition ends, whether it finished or was cut short.
signal transition_finished

## Name or color currently shown, for saves.
var current: Variant = Color.BLACK

var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween
var _running := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = TRANSITION_SHADER
	_rect.material = _material
	add_child(_rect)
	_set_side("to", Color.BLACK)
	_material.set_shader_parameter("progress", 1.0)
	resized.connect(_update_screen_size)
	_update_screen_size()


## Shows [param source] (a Texture2D or Color). Awaitable: returns when the
## transition ends. [param mask] is an optional grayscale texture for
## "dissolve".
func show_backdrop(source: Variant, label: Variant, transition := "fade", time := 1.0, mask: Texture2D = null, skip := false) -> void:
	if not TRANSITIONS.has(transition):
		push_warning("StoryTeller: unknown transition '%s', using fade." % transition)
		transition = "fade"
	finish()
	_copy_to_from()
	_set_side("to", source)
	current = label
	var settings: Array = TRANSITIONS[transition]
	_material.set_shader_parameter("mode", settings[0])
	_material.set_shader_parameter("direction", settings[1])
	_material.set_shader_parameter("has_mask", mask != null)
	if mask != null:
		_material.set_shader_parameter("mask_tex", mask)
	if time <= 0.0 or skip or settings[0] == 0 or not is_inside_tree():
		_material.set_shader_parameter("progress", 1.0)
		return
	_material.set_shader_parameter("progress", 0.0)
	_running = true
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("progress", value), 0.0, 1.0, time)
	_tween.finished.connect(finish)
	await transition_finished


## Jumps to the end of a running transition. Anything waiting for it
## continues.
func finish() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_material.set_shader_parameter("progress", 1.0)
	if _running:
		_running = false
		transition_finished.emit()


## Current transition progress from 0 to 1, for tests.
func get_progress() -> float:
	return _material.get_shader_parameter("progress")


func _copy_to_from() -> void:
	for key in ["tex", "has_tex", "color", "size"]:
		_material.set_shader_parameter("from_" + key, _material.get_shader_parameter("to_" + key))


func _set_side(side: String, source: Variant) -> void:
	if source is Texture2D:
		_material.set_shader_parameter(side + "_tex", source)
		_material.set_shader_parameter(side + "_has_tex", true)
		_material.set_shader_parameter(side + "_size", Vector2(source.get_size()))
	else:
		_material.set_shader_parameter(side + "_has_tex", false)
		_material.set_shader_parameter(side + "_color", source if source is Color else Color.BLACK)


func _update_screen_size() -> void:
	if _material and size.x > 0 and size.y > 0:
		_material.set_shader_parameter("screen_size", size)

class_name BackdropView
extends Control
## Full-screen backdrop that blends between images or colors with a
## transition shader. Transitions are the built-in ones in [constant TRANSITIONS]
## or a [StoryTransition] in [member transitions].

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

## Uniforms that describe the two pictures, kept here so a transition with
## its own shader can take over and hand back.
const SIDE_UNIFORMS: Array[String] = [
	"from_tex", "from_has_tex", "from_color", "from_size",
	"to_tex", "to_has_tex", "to_color", "to_size", "screen_size",
]

## Extra transitions by name, shared with the stage (see
## [method StoryStage.add_transition]).
var transitions: Dictionary = {}

## Name or color currently shown, for saves. Starts transparent so the game
## shows through until a tale picks a backdrop.
var current: Variant = Color.TRANSPARENT

var _rect: ColorRect
## The material in use: the built-in one, or a transition's own shader.
var _material: ShaderMaterial
var _default_material: ShaderMaterial
var _tween: Tween
var _running := false
## Current values of [constant SIDE_UNIFORMS].
var _sides: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_default_material = ShaderMaterial.new()
	_default_material.shader = TRANSITION_SHADER
	_material = _default_material
	_rect.material = _material
	add_child(_rect)
	_set_side("to", Color.TRANSPARENT)
	_material.set_shader_parameter("progress", 1.0)
	resized.connect(_update_screen_size)
	_update_screen_size()


## Shows [param source] (a Texture2D or Color). Awaitable: returns when the
## transition ends. [param mask] is an optional grayscale texture for
## "dissolve".
func show_backdrop(source: Variant, label: Variant, transition := "fade", time := 1.0, mask: Texture2D = null, skip := false) -> void:
	if not has_transition(transition):
		push_warning("StoryTeller: unknown transition '%s', using fade." % transition)
		transition = "fade"
	finish()
	_copy_to_from()
	_set_side("to", source)
	current = label
	var custom: StoryTransition = transitions.get(transition) if not TRANSITIONS.has(transition) else null
	var mode := 0
	if custom != null and custom.shader != null:
		_use_material(_material_for(custom))
		mode = 1
	else:
		_use_material(_default_material)
		var settings: Array = TRANSITIONS[transition] if custom == null else [int(custom.mode), custom.direction]
		mode = settings[0]
		_material.set_shader_parameter("mode", settings[0])
		_material.set_shader_parameter("direction", settings[1])
		_material.set_shader_parameter("smoothness", custom.softness if custom != null else 0.08)
		if mask == null and custom != null:
			mask = custom.mask
	_material.set_shader_parameter("has_mask", mask != null)
	if mask != null:
		_material.set_shader_parameter("mask_tex", mask)
	if time <= 0.0 or skip or mode == 0 or not is_inside_tree():
		_material.set_shader_parameter("progress", 1.0)
		_use_material(_default_material)
		return
	_material.set_shader_parameter("progress", 0.0)
	_running = true
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("progress", value), 0.0, 1.0, time)
	_tween.finished.connect(finish)
	await transition_finished


## True if [param transition_name] is built in or in [member transitions].
func has_transition(transition_name: String) -> bool:
	return TRANSITIONS.has(transition_name) or transitions.get(transition_name) is StoryTransition


## Names of every transition this view knows, built-in ones first.
func get_transition_names() -> PackedStringArray:
	var names := PackedStringArray(TRANSITIONS.keys())
	for transition_name in transitions:
		if transition_name not in names:
			names.append(transition_name)
	return names


## Jumps to the end of a running transition. Anything waiting for it
## continues.
func finish() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	# A transition's own shader draws only while it runs.
	_use_material(_default_material)
	_material.set_shader_parameter("progress", 1.0)
	if _running:
		_running = false
		transition_finished.emit()


## Current transition progress from 0 to 1, for tests.
func get_progress() -> float:
	return _material.get_shader_parameter("progress")


## The material in use, for tests and for transitions that need it.
func get_material_in_use() -> ShaderMaterial:
	return _material


func _copy_to_from() -> void:
	for key in ["tex", "has_tex", "color", "size"]:
		_set_uniform("from_" + key, _sides.get("to_" + key))


func _set_side(side: String, source: Variant) -> void:
	if source is Texture2D:
		_set_uniform(side + "_tex", source)
		_set_uniform(side + "_has_tex", true)
		_set_uniform(side + "_size", Vector2(source.get_size()))
	else:
		_set_uniform(side + "_has_tex", false)
		_set_uniform(side + "_color", source if source is Color else Color.TRANSPARENT)


func _set_uniform(uniform: String, value: Variant) -> void:
	_sides[uniform] = value
	_material.set_shader_parameter(uniform, value)


## Switches to [param material], giving it the current pictures.
func _use_material(material: ShaderMaterial) -> void:
	if material == _material:
		return
	_material = material
	for uniform in _sides:
		_material.set_shader_parameter(uniform, _sides[uniform])
	if _rect != null:
		_rect.material = _material


func _material_for(transition: StoryTransition) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = transition.shader
	for uniform in transition.parameters:
		material.set_shader_parameter(uniform, transition.parameters[uniform])
	return material


func _update_screen_size() -> void:
	if _material and size.x > 0 and size.y > 0:
		_set_uniform("screen_size", size)

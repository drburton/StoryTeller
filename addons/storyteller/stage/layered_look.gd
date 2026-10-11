@tool
class_name LayeredLook
extends CastLook
## Builds a character from layer groups such as body, outfit, and face.
##
## A mood is either a preset name or a list of choices, e.g.
## [code]"face=smile, outfit=coat"[/code]. Groups not mentioned keep their
## current choice.

## Group name to {choice name: Texture2D}.
@export var groups: Dictionary = {}
## Drawing order of the groups, back to front.
@export var order: PackedStringArray = []
## Choice used for each group when nothing else is set.
@export var defaults: Dictionary = {}
## Preset mood name to a choice list, e.g. {"happy": "face=smile, arms=open"}.
@export var presets: Dictionary = {}


func create_visual() -> Node2D:
	var root := Node2D.new()
	root.name = "Layers"
	for group in _group_order():
		var sprite := Sprite2D.new()
		sprite.name = group
		root.add_child(sprite)
		if defaults.has(group):
			_set_choice(root, group, defaults[group])
	return root


func apply_mood(visual: Node2D, mood: String) -> bool:
	var choices := parse_choices(presets.get(mood, mood))
	if choices.is_empty():
		return false
	for group in choices:
		if not groups.has(group) or not groups[group].has(choices[group]):
			return false
	for group in choices:
		_set_choice(visual, group, choices[group])
	return true


func get_moods() -> PackedStringArray:
	var names := PackedStringArray(presets.keys())
	for group in groups:
		for choice in groups[group]:
			names.append("%s=%s" % [group, choice])
	return names


## The default layers with [param mood] applied, drawn into one image.
## Layers line up at the bottom center, as on stage.
func get_preview(mood: String) -> Texture2D:
	var choices := defaults.duplicate()
	choices.merge(parse_choices(presets.get(mood, mood)), true)
	var images: Array[Image] = []
	var size := Vector2i.ZERO
	for group in _group_order():
		var texture: Texture2D = groups.get(group, {}).get(choices.get(group, ""))
		if texture == null:
			continue
		var image := texture.get_image()
		if image == null:
			continue
		image = image.duplicate()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
		size = size.max(image.get_size())
	if images.is_empty():
		return null
	var canvas := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for image in images:
		var at := Vector2i((size.x - image.get_width()) / 2, size.y - image.get_height())
		canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), at)
	return ImageTexture.create_from_image(canvas)


## Parses "a=b, c=d" into {"a": "b", "c": "d"}. Returns {} if malformed.
static func parse_choices(text: String) -> Dictionary:
	var choices := {}
	for part in text.split(",", false):
		var pair := part.split("=")
		if pair.size() != 2 or pair[0].strip_edges().is_empty() or pair[1].strip_edges().is_empty():
			return {}
		choices[pair[0].strip_edges()] = pair[1].strip_edges()
	return choices


func _group_order() -> PackedStringArray:
	var names := order.duplicate()
	for group in groups:
		if group not in names:
			names.append(group)
	return names


func _set_choice(visual: Node2D, group: String, choice: String) -> void:
	var sprite := visual.get_node_or_null(NodePath(group)) as Sprite2D
	var texture: Texture2D = groups.get(group, {}).get(choice)
	if sprite == null or texture == null:
		return
	sprite.texture = texture
	sprite.offset = Vector2(0, -texture.get_height() / 2.0)

@tool
class_name CastProfile
extends Resource
## Everything StoryTeller needs to know about one character.
##
## Save as [code]res://story/cast/<id>.tres[/code], or skip the file and put
## mood images in [code]res://story/cast/<id>/[/code] to get a profile
## with default settings.

## Name used in tales, e.g. "mira". Defaults to the file or folder name.
@export var id := ""
## Name shown in the dialogue box. Defaults to the id, capitalized.
@export var display_name := ""
## Color of the name in the dialogue box.
@export var name_color := Color.WHITE
## How the character is drawn.
@export var look: CastLook
## Mood used when the character first appears without one.
@export var default_mood := ""
## Size multiplier applied to the look.
@export var scale := 1.0
## Data the character keeps during a story, with starting values, such as
## [code]{"affection": 0, "met": false}[/code]. Tales read and change it
## like properties ([code]ada.affection += 1[/code]); it is saved with the
## story and starts over in a new game. Names must be identifiers and must
## differ from the cast member's own members, such as [code]mood[/code].
@export var fields: Dictionary = {}


func get_display_name() -> String:
	return display_name if not display_name.is_empty() else id.capitalize()


## Names in [member fields] that tales can use, sorted.
func get_field_names() -> PackedStringArray:
	var names := PackedStringArray()
	for field in fields:
		if is_valid_field_name(str(field)):
			names.append(str(field))
	names.sort()
	return names


## Problems with [member fields], such as names that clash with the cast
## member's own methods and properties.
func get_field_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	for field in fields:
		if not is_valid_field_name(str(field)):
			problems.append("Cast member '%s' can't have a field named '%s': field names must be identifiers and can't be the name of a cast member property or method, such as 'mood' or 'position'." % [id, field])
	return problems


## Field names must be identifiers that don't hide a property or method of
## [CastMember] (including those of [Node2D]).
static func is_valid_field_name(field: String) -> bool:
	return field.is_valid_ascii_identifier() and not reserved_names().has(field)


static var _reserved: Dictionary = {}


static func reserved_names() -> Dictionary:
	if _reserved.is_empty():
		for field in TaleCompletion.CAST_METHODS + TaleCompletion.CAST_PROPERTIES:
			_reserved[field] = true
		for property in ClassDB.class_get_property_list("Node2D"):
			_reserved[property["name"]] = true
		for method in ClassDB.class_get_method_list("Node2D"):
			_reserved[method["name"]] = true
		var script: Script = load("res://addons/storyteller/stage/cast_member.gd")
		for property in script.get_script_property_list():
			_reserved[property["name"]] = true
		for method in script.get_script_method_list():
			_reserved[method["name"]] = true
	return _reserved

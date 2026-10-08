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


func get_display_name() -> String:
	return display_name if not display_name.is_empty() else id.capitalize()

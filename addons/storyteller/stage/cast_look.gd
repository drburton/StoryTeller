@tool
class_name CastLook
extends Resource
## How a cast member is drawn. Subclasses build a visual node and switch it
## between moods.


## Creates the node that draws the cast member. Its origin is the bottom
## center of the character.
func create_visual() -> Node2D:
	return Node2D.new()


## Changes [param visual] to [param mood]. Returns false for unknown moods.
func apply_mood(_visual: Node2D, _mood: String) -> bool:
	return false


## Mood names this look supports, or an empty list when any name may work.
func get_moods() -> PackedStringArray:
	return PackedStringArray()

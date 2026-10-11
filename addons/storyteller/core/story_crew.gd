class_name StoryCrew
extends Node
## Base class for StoryTeller runtime systems, called crew members.
##
## Audio, saves, rewind, the cast, and every other runtime system extend this
## class. The [code]Story[/code] autoload creates crew members from
## [member StoryConfig.crew], and projects can swap any built-in member for a
## subclass of their own.


## Unique key used to look this member up with [code]Story.get_crew()[/code]
## and to store its state in saves. Defaults to the script's
## [code]class_name[/code]. Override to choose a different key.
func get_crew_name() -> StringName:
	var script := get_script() as Script
	if script == null:
		return &""
	return script.get_global_name()


## Called once when the story starts, after the member joins the scene tree.
func setup(_config: StoryConfig) -> void:
	pass


## Resets the member to its initial state, for example on a new game.
func clear() -> void:
	pass


## Returns this member's state for saves and rewind. The dictionary must only
## contain values that survive JSON serialization.
func capture() -> Dictionary:
	return {}


## Restores state previously returned by [method capture].
func restore(_data: Dictionary) -> void:
	pass


## Called before the member is removed, so it can release resources.
func teardown() -> void:
	pass

extends Control
## Starts "Where's Biscuit?" with its own StoryConfig and opens the title
## screen. Open this scene and press F6 (Run Current Scene) to play.

const CONFIG := "res://examples/wheres_biscuit/story_config.tres"


func _ready() -> void:
	Story.start(load(CONFIG))
	Story.show_title()

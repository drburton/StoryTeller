extends Control
## Starts "Robo's Lost Beep" with its own StoryConfig and opens the title
## screen. Open this scene and press F6 (Run Current Scene) to play.

const CONFIG := "res://examples/robos_lost_beep/story_config.tres"


func _ready() -> void:
	Story.start(load(CONFIG))
	Story.show_title()

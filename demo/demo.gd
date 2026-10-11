extends Control
## Opens the demo's title screen. New Game plays welcome.tale (set as
## start_tale in demo/story_config.tres), and the title screen returns when
## the story ends.
##
## In the story: Space, Enter, or a click continues; hold Ctrl to skip;
## press A for auto mode, Escape for the pause menu, H for the history, and
## Page Up or the mouse wheel to rewind.


func _ready() -> void:
	Story.show_title()

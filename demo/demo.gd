extends Control
## Plays the demo tale. Space, Enter, or a click continues; hold Ctrl to
## skip; press A to toggle auto mode.

@onready var _end_label: Label = $EndLabel


func _ready() -> void:
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.tales_folder = "res://demo/tales"
	await Story.play("welcome")
	var dialogue := Story.get_crew(&"Dialogue") as StoryDialogue
	dialogue.dialogue_box.hide_box()
	_end_label.show()

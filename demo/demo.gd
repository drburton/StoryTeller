extends Control
## Plays the demo tale. Space, Enter, or a click continues; hold Ctrl to
## skip; press A to toggle auto mode.

@onready var _end_label: Label = $EndLabel


func _ready() -> void:
	await Story.play("welcome")
	var dialogue := Story.get_crew(&"Dialogue") as StoryDialogue
	dialogue.dialogue_box.hide_box()
	_end_label.show()

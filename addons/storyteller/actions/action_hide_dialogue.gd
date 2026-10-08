extends TaleAction
## hide_dialogue(): hides the dialogue box, for example during a scene change.
## The next line shows it again.


func get_action_name() -> String:
	return "hide_dialogue"


func run(ctx: TaleContext) -> void:
	var dialogue := ctx.get_crew(&"Dialogue") as StoryDialogue
	if dialogue != null:
		dialogue.dialogue_box.hide_box()

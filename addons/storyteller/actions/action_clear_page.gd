extends TaleAction
## clear_page(): starts a new page in the "page" dialogue style.


func get_action_name() -> String:
	return "clear_page"


func run(ctx: TaleContext) -> void:
	var dialogue := ctx.get_crew(&"Dialogue") as StoryDialogue
	if dialogue != null:
		dialogue.dialogue_box.clear_page()

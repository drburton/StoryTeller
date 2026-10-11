extends TaleAction
## dialogue_style(name): switches between dialogue styles, such as "classic"
## (a box at the bottom) and "page" (full-screen text).


func get_action_name() -> String:
	return "dialogue_style"


func run(ctx: TaleContext, name: String) -> void:
	var dialogue := ctx.get_crew(&"Dialogue") as StoryDialogue
	if dialogue == null:
		ctx.fail("dialogue_style() needs the Dialogue crew member.")
	elif not dialogue.set_style(name):
		ctx.fail("Unknown dialogue style '%s'. Styles: %s." % [name, ", ".join(dialogue.get_style_names())])

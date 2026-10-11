extends TaleAction
## exit_all(time = 0.4): every cast member on stage exits.


func get_action_name() -> String:
	return "exit_all"


func run(ctx: TaleContext, time: float = 0.4) -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage == null:
		ctx.fail("exit_all() needs the Stage crew member.")
		return
	await stage.exit_all(time)

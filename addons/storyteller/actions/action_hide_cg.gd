extends TaleAction
## hide_cg(transition = "fade", time = 1.0): removes the CG and shows the
## stage again.


func get_action_name() -> String:
	return "hide_cg"


func run(ctx: TaleContext, transition: String = "fade", time: float = 1.0) -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage == null:
		ctx.fail("hide_cg() needs the Stage crew member.")
		return
	await stage.hide_cg(transition, time)

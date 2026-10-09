extends TaleAction
## cg(name, variant = "", transition = "fade", time = 1.0): shows a CG, a
## full-screen event picture from the CG folder, over the stage. A CG folder
## holds one image per variant; variant picks one ("" shows "default" or the
## first). Showing a CG unlocks its gallery entry. Transitions are the same
## as for backdrop().


func get_action_name() -> String:
	return "cg"


func run(ctx: TaleContext, name: String, variant: String = "", transition: String = "fade", time: float = 1.0) -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage == null:
		ctx.fail("cg() needs the Stage crew member.")
		return
	var problem: String = await stage.show_cg(name, variant, transition, time)
	if not problem.is_empty():
		ctx.fail(problem)

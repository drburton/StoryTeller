extends TaleAction
## prop(name, at = Vector2(0.5, 0.5), time = 0.3): shows an image or scene from
## the prop folder, centered at a stage position.


func get_action_name() -> String:
	return "prop"


func run(ctx: TaleContext, name: String, at: Vector2 = Vector2(0.5, 0.5), time: float = 0.3) -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage == null:
		ctx.fail("prop() needs the Stage crew member.")
		return
	var problem: String = await stage.show_prop(name, at, time)
	if not problem.is_empty():
		ctx.fail(problem)

extends TaleAction
## backdrop(name, transition = "fade", time = 1.0, mask = ""): shows a backdrop
## image from the backdrop folder, or a Color such as Color.BLACK.
## Color.TRANSPARENT removes the backdrop and shows the game behind it.
## Transitions: none, fade, dissolve, wipe_left/right/up/down,
## slide_left/right/up/down, and any [StoryTransition] the project adds.
## [code]mask[/code] names a grayscale image in the transition folder for
## "dissolve".


func get_action_name() -> String:
	return "backdrop"


func run(ctx: TaleContext, name: Variant, transition: String = "fade", time: float = 1.0, mask: String = "") -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage == null:
		ctx.fail("backdrop() needs the Stage crew member.")
		return
	var problem: String = await stage.show_backdrop(name, transition, time, mask)
	if not problem.is_empty():
		ctx.fail(problem)

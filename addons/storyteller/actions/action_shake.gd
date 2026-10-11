extends TaleAction
## shake(strength = 0.5, time = 0.4): shakes the stage. Same as camera.shake().


func get_action_name() -> String:
	return "shake"


func run(ctx: TaleContext, strength: float = 0.5, time: float = 0.4) -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage != null:
		await stage.camera.shake(strength, time)

extends TaleAction
## fade_in(time = 0.5): fades the screen back in after fade_out().


func get_action_name() -> String:
	return "fade_in"


func run(ctx: TaleContext, time: float = 0.5) -> void:
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("fade_in() needs the Effects crew member.")
		return
	await effects.fade_in(time)

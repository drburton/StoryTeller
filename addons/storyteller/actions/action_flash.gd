extends TaleAction
## flash(color = Color.WHITE, time = 0.3): flashes the whole screen.


func get_action_name() -> String:
	return "flash"


func run(ctx: TaleContext, color: Color = Color.WHITE, time: float = 0.3) -> void:
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("flash() needs the Effects crew member.")
		return
	await effects.flash(color, time)

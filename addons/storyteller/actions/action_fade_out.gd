extends TaleAction
## fade_out(color = Color.BLACK, time = 0.5): fades the whole screen,
## dialogue box included, to a color. fade_in() brings it back.


func get_action_name() -> String:
	return "fade_out"


func run(ctx: TaleContext, color: Color = Color.BLACK, time: float = 0.5) -> void:
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("fade_out() needs the Effects crew member.")
		return
	await effects.fade_out(color, time)

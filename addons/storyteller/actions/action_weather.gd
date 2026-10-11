extends TaleAction
## weather(kind, strength = 1.0, fade = 1.0): starts "rain" or "snow" over
## the stage, or stops it with "none".


func get_action_name() -> String:
	return "weather"


func run(ctx: TaleContext, kind: String, strength: float = 1.0, fade: float = 1.0) -> void:
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("weather() needs the Effects crew member.")
		return
	var problem: String = await effects.set_weather(kind, strength, fade)
	if not problem.is_empty():
		ctx.fail(problem)

extends TaleAction
## filter(name, strength = 1.0, time = 0.5): recolors the stage with
## "grayscale", "sepia", "night", "warm", or "cold". filter("none") removes
## it. The dialogue box and menus keep their colors.


func get_action_name() -> String:
	return "filter"


func run(ctx: TaleContext, name: String, strength: float = 1.0, time: float = 0.5) -> void:
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("filter() needs the Effects crew member.")
		return
	var problem: String = await effects.set_filter(name, strength, time)
	if not problem.is_empty():
		ctx.fail(problem)

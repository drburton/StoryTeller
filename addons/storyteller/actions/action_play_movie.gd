extends TaleAction
## play_movie(name, skippable = true): plays a movie from the movie folder
## (Ogg Theora .ogv) over the stage and dialogue box. A click or the
## continue key skips it when skippable. Use with await to wait for it.


func get_action_name() -> String:
	return "play_movie"


func run(ctx: TaleContext, name: String, skippable: bool = true) -> void:
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("play_movie() needs the Effects crew member.")
		return
	var problem: String = await effects.play_movie(name, skippable)
	if not problem.is_empty():
		ctx.fail(problem)

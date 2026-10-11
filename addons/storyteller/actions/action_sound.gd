extends TaleAction
## sound(name, volume = 1.0): plays a sound effect from the sounds folder.
## Use await to wait until it ends.


func get_action_name() -> String:
	return "sound"


func run(ctx: TaleContext, name: String, volume: float = 1.0) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio == null:
		ctx.fail("sound() needs the Audio crew member.")
		return
	var problem: String = await audio.play_sound(name, volume)
	if not problem.is_empty():
		ctx.fail(problem)

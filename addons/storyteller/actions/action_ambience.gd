extends TaleAction
## ambience(name, volume = 1.0, fade = 1.0): plays a looping background sound
## (rain, crowd noise) from the ambience folder.


func get_action_name() -> String:
	return "ambience"


func run(ctx: TaleContext, name: String, volume: float = 1.0, fade: float = 1.0) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio == null:
		ctx.fail("ambience() needs the Audio crew member.")
		return
	var problem := audio.play_ambience(name, volume, fade)
	if not problem.is_empty():
		ctx.fail(problem)

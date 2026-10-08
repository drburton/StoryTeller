extends TaleAction
## music(track, volume = 1.0, fade = 1.0, loop = true): plays a music track
## from the music folder, crossfading from the current one.


func get_action_name() -> String:
	return "music"


func run(ctx: TaleContext, track: String, volume: float = 1.0, fade: float = 1.0, loop: bool = true) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio == null:
		ctx.fail("music() needs the Audio crew member.")
		return
	var problem := audio.play_music(track, volume, fade, loop)
	if not problem.is_empty():
		ctx.fail(problem)

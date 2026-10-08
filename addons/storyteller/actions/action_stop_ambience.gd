extends TaleAction
## stop_ambience(fade = 1.0): fades out the ambience.


func get_action_name() -> String:
	return "stop_ambience"


func run(ctx: TaleContext, fade: float = 1.0) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio != null:
		audio.stop_ambience(fade)

extends TaleAction
## stop_audio(fade = 0.5): stops music, ambience, sounds, and voice.


func get_action_name() -> String:
	return "stop_audio"


func run(ctx: TaleContext, fade: float = 0.5) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio != null:
		audio.stop_all(fade)

extends TaleAction
## stop_music(fade = 1.0): fades out the music.


func get_action_name() -> String:
	return "stop_music"


func run(ctx: TaleContext, fade: float = 1.0) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio != null:
		audio.stop_music(fade)

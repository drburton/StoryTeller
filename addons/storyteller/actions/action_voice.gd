extends TaleAction
## voice(clip): plays a voice clip from the voice folder. Lines marked
## @voice("clip") play their clip automatically, so this is only needed for
## voices outside dialogue.


func get_action_name() -> String:
	return "voice"


func run(ctx: TaleContext, clip: String) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio == null:
		ctx.fail("voice() needs the Audio crew member.")
		return
	var problem: String = await audio.play_voice(clip)
	if not problem.is_empty():
		ctx.fail(problem)
